package Koha::Borrower::Import;

# This file is part of Koha.
#
# Copyright 2014 PTFS Europe
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Text::CSV;
use JSON;
use DateTime;

use C4::Context;
use C4::Dates;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::Messaging;

use Koha::Borrower::Debarments;

use parent qw( Exporter );

our @EXPORT_OK = qw(
    importBorrowers
);

=head1 Koha::Borrower::Imports

Koha::Borrower::Imports - Module for managing csv borrower imports

=cut

=head2 importBorrowers

FIXME: my $result = importBorrowers( $inputfile, $defaults, $matchpoint, $logfilename );

=cut

sub importBorrowers {

    # Get Variables
    my ( $inputfile, $defaults, $matchpoint, $logfilename ) = @_;

    # Runtime ID for log
    my $runid = DateTime->now;

    # Hash for loghandler
    my %logger = ( id => $runid );

    # Hash to store return value
    my %retval;

    # Track fatal errors
    $retval{fatal} = 0;
    $logger{fatal} = 0;

    # Open log file
    unless ( open( my $logfile, '>', $logfilename ) ) {
        push @{ $retval->{errors} },
            "Cannot open shared '$logfilename' for logging. $!";
        $retval{fatal} = 1;
    } else {
        # Send success to logger
        $logger{feedback} = [ "Logfile successfully opened", "$logfilename" ];

        my $log_json = $json->encode ($logger);
        say $logfile $log_json;

        # Reset Logger
        %logger = ( id => $runid );
    }

    # Static Variables
    my $today_iso = C4::Dates->new()->output('iso');
    my $date_re   = C4::Dates->new()->regexp('syspref');
    my $iso_re    = C4::Dates->new()->regexp('iso');

    # Tracking Variables
    $retval{count} = 0;    # Count number of records processed

    # CSV Handler
    our $csv = Text::CSV->new( { binary => 1 } )
        ;                  # binary needed for non-ASCII Unicode

    # DB Columns
    my %dbfields = map { $_ => { 'mandatory' => '0' } } C4::Members::columns();
    my $extended = C4::Context->preference('ExtendedPatronAttributes');
    if ($extended) {
        $dbfields{patron_attributes}{mandatory} = 0;
    }

    # Mandatory Fields
    # FIXME: Currently patron-attributes cannot be set as required, so we can
    # safely ignore handling them. If the 'required' flag is ever implimented,
    # then this will also need to handle patron attributes limited by branch.
    my $borrowerMandatoryField
        = C4::Context->preference("BorrowerMandatoryField");

    # Remove cardnumber from mandatory fields if autoMemberNum or checkdigit
    # is on.
    my $autonumber_members = C4::Context->boolean_preference('autoMemberNum')
        || 0;
    if ($autonumber_members) {
        $borrowerMandatoryField =~ s/cardnumber//;
        $borrowerMandatoryField =~ s/\|\|/\|/;
    }

    # Add mandatory_fields to an array
    my @mandatory_fields = split( /\|/, $borrowerMandatoryField );

    # Set fields as mandatory in dbfields hash.
    foreach my $mandatory (@mandatory_fields) {
        if ( $dbfields{$mandatory} ) {
            $dbfields{$mandatory}{mandatory} = 1;
        }
    }
    $dbfields{$matchpoint}{mandatory} = 1;

    # Set merge paramter for fields
    # FIXME: This needs implimenting
    $dbfields{$matchpoint}{merge} = 1;

    # Parse CSV File
    ################

    #
    # Handle Header Row

    # Get column keys from csv heading line
    my @csvfields = @{ $csv->getline($inputfile) };

    # Bind column names
    my $borrower = {};
    $csv->bind_columns( \@{$borrower}{@csvfields} );

    # Check that mandatory fields are present in csvfields array
    while ( ( $dbfield, $data ) = each %dbfields ) {
        if ( $dbfields{$dbfield}{'mandatory'} == '1' ) {
            unless ( exists $borrower{$dbfield} ) {
                push @{ $retval->{errors} }, "$dbfield is a mandatory column";
                $retval{fatal} = 1;
            }
        }
    }

    # Report any csvfields that do not appear in the database
    foreach my $csvfield (@csvfields) {
        unless ( exists $dbfields{$csvfield} ) {
            push @{ $retval->{errors} },
                "$csvfield is not a koha field, it will be skipped";
        }
    }

    # Die now if the header row suggests problems
    if ( $retval{fatal} == 1 ) {
        return $retval;
    }

    #
    # Handle Borrower Rows
    # Iterate through file
RECORD: while ( $csv->getline($inputfile) ) {

        # Reset Logger
        %logger = ( id => $runid );

        # Track file progress and add to logger
        $logger{linenumber} = $retval{count}++;
        $logger{data} = join(q{,}, map{qq{"$borrower{$_}"} keys %borrower); # FIXME: Check this is correct

        #
        # Prepare Borrower

        # Set defaults for missing fields as per merge rules
        my $baddefault = _setDefaults( $borrower, $dbfields );
        if ($baddefault) {
            push @{ $logger->{error} },
                ["Could not assign defaults"];    # Report Error
        }

        # Check that mandatory fields are present
        my @missing = _checkMandatory( $borrower, \@mandatory_fields );
        if (@present) {
            push @{ $logger{error} },
                [ "Missing mandatory fields", "@missing" ];    # Report Error
        }

        # Check that fields are not malformed
        my @malformed = _checkMalformed($borrower);
        if (@malformed) {
            push @{ $logger->{error} },
                [ "Malformed fields found", "@malformed" ];    # Report Error
        }

        # Correct malformed date fields
        my @baddates = _setDates($borrower);
        if (@baddates) {
            push @{ $logger{error} },
                [ "Malformed dates found", "@baddates" ];
        }

        # Split out borrower messaging preferences
        if ($messaging) {

            # FIXME
        }

        # Split out borrower attributes
        if ($extended) {
            my $attr_str = $borrower{patron_attributes};
            $attr_str =~ s/\xe2\x80\x9c/"/g
                ;    # fixup double quotes in case we are passed smart quotes
            $attr_str =~ s/\xe2\x80\x9d/"/g;
            push @feedback,
                {
                feedback => 1,
                name     => 'attribute string',
                value    => $attr_str,
                filename => $uploadborrowers
                };
            delete
                $borrower{patron_attributes}; # not really a field in borrowers, so we don't want to pass it to ModMember.
            $patron_attributes
                = extended_attributes_code_value_arrayref($attr_str);
        }

        # Report and skip erroneous records
        if ( $logger{error} ) {
            # Send to logger
            my $log_json = $json->encode ($logger);
            say $logfile $log_json;

            # Skip to next record
            next RECORD;
        }

        # Attempt to import
        ###################

        # Test for borrower existance
        my $member;

        # Matchpoint in borrowers table
        if (   ( exists $dbfields{$matchpoint} )
            && ( defined $borrower{$matchpoint} ) )
        {
            $member = GetMember(
                $dbfields{$matchpoint} => $borrower{$matchpoint} );
        }

        # Matchpoint in borrower attributes table
        elsif ($extended) {
            my $matchpoint_attr_type
                = C4::Members::AttributeTypes->fetch($matchpoint);
            if ($matchpoint_attr_type) {
                foreach my $attr (@$patron_attributes) {
                    if (    $attr->{code} eq $matchpoint
                        and $attr->{value} ne '' )
                    {
                        my @borrowernumbers
                            = $matchpoint_attr_type->get_patrons(
                            $attr->{value} );
                        my $borrowernumber = $borrowernumbers[0]
                            if scalar(@borrowernumbers) == 1;
                        $member
                            = GetMember( borrowernumber => $borrowernumber )
                            last;
                    }
                }
            }
        }

        # Borrower exists, attempt update...
        if ($member) {
            $retval{present}          = 1;
            $borrower{borrowernumber} = $member->{'borrowernumber'};

            # Last Minute Borrower Import Preperation

            # Overwrite, Update and Reset rules taken
            # account of in _setDefaults

            # Merge - Only add new values in CSV to DB
            foreach my $csvfield ( keys %$borrower ) {
                if ( $dbfields{$csvfield}{rule} == 'M' ) {
                    if (   $member->{"$csvfield"}
                        && $member->{"$csvfield"} ne '' )
                    {
                        delete $borrower{"$csvfield"};
                    }

                    # If zero non-whitespace characters are found,
                    # we wish to leave field undefined
                    if ( $borrower{$csvfield} !~ /\S/ ) {
                        delete $borrower{"$csvfield"};
                    }
                }
            }

            # Update borrower attributes before core
            # (it's easier to reverse attributes updates, than a core update)
            my $old_attributes
                = GetBorrowerAttributes( $borrower{borrowernumber} );

            # FIXME: We should really do somthing clever
            # on a per attribute basis for merge rules here

            my $new_attributes = extended_attributes_merge( $old_attributes,
                $patron_attributes, 1 );

            # Clean out old attributes before uniqueness check
            foreach my $attr (@old_attributes) {
                DeleteBorrowerAttribute( $borrowernumber, $attr );
            }

            # Check merged set doesn't violate uniqueness constraints
            my $die;
            foreach my $attr (@$new_attributes) {
                unless (
                    CheckUniqueness(
                        $attr->{code}, $attr->{attribute},
                        $borrower{borrowernumber}
                    )
                    )
                {
                    say $uerror_log
                        " Update Error: CheckUniqueness failed for borrower: "
                        . 'http://sthc-staff.koha-ptfs.co.uk/cgi-bin/koha/members/moremember.pl?borrowernumber='
                        . $borrowernumber;
                    $die++;
                }
            }

            # CheckUniqueness failed,
            # we should restore OLD attributes and abort update.
            if ($die) {

                # Rollback Attributes Update
                SetBorrowerAttributes( $borrower{'borrowernumber'},
                    $old_attributes );

                # Report Error

                # Skip Record
                next RECORD;
            }

            # Update core record
            if ( ModMember(%borrower) ) {
                say $live_log " Update Progress: ModMember ran successfully";
            }

            # ModMember Failed,
            # we should roll back the attributes update and report failure
            else {
                # Rollback Attributes Update
                SetBorrowerAttributes( $borrower{'borrowernumber'},
                    $old_attributes );

                # Report Error

                # Skip Record
                next RECORD;
            }

            # Update Debarments
            if ( $borrower{debarred} ) {

                # Check to see if this debarment already exists
                my $debarrments = GetDebarments(
                    {   borrowernumber => $borrowernumber,
                        expiration     => $borrower{debarred},
                        comment        => $borrower{debarredcomment}
                    }
                );

                # If it doesn't, then add it!
                unless (@$debarrments) {
                    AddDebarment(
                        {   borrowernumber => $borrowernumber,
                            expiration     => $borrower{debarred},
                            comment        => $borrower{debarredcomment}
                        }
                    );
                }
            }
        }

        # Borrower is new, attempt add...
        else {

            # Last Minute Borrower Import Preperation

            # This is a new borrower, therefor Merge rule should
            # resort back to 'defaults'.
            foreach my $csvfield ( keys %$borrower ) {
                if ( $dbfields{$csvfield}{rule} == 'M' ) {

                    # If zero non-whitespace characters are found,
                    # we wish to set field with default values
                    if ( $borrower{$csvfield} !~ /\S/ ) {
                        $borrower{$csvfield} = $dbfields{$csvfield}{$default};
                    }
                }
            }

            if ( !$borrower{'cardnumber'} ) {

                # FIXME: We should really impliment
                # a table lock/transaction here..
                $borrower{'cardnumber'} = fixup_cardnumber(undef);
            }

            if ( $borrowernumber = AddMember(%learner) ) {
                if ( $borrower{debarred} ) {
                    my $debarment = {
                        borrowernumber => $borrowernumber,
                        expiration     => $borrower{debarred},
                        comment        => $borrower{debarredcomment}
                    };

                    if ( AddDebarment($debarment) ) {

                    }

                    # AddDebarment failed
                    else {
                        # Cleanup partial import
                        DelMember($borrowernumber);

                        # Report failure
                    }
                }

                if ($extended) {
                    if (SetBorrowerAttributes(
                            $borrowernumber, $patron_attributes
                        )
                        )
                    {

                    }

                    # Attributes import failed
                    else {
                        # Cleanup partial import
                        DelMember($borrowernumber);

                        # FIXME: Report Failure
                    }
                }

                # No borrower attributes to insert and AddMember succeeded
                else {
                    # Report Success
                }
            }

            # AddMember failed
            else {
                # Report failure
            }

        }

    }

    # If complete set, handle delete operation
    if ($complete) {

    }
}

sub _checkMandatory {
    my ( $borrower, $mandatories ) = @_;
    my @fail;
    foreach my $mandatory_field (@$mandatories) {
        unless ( defined $borrower->{$mandatory_field} ) {
            push( @fail, $mandatory_field );
        }
    }
    return @fail;
}

sub _checkMalformed {
    my $borrower = $_;
    my @fail;
    if ( $borrower{categorycode} ) {
        unless ( GetBorrowercategory( $borrower{categorycode} ) ) {
            push( @fail, 'categorycode' );
        }
    }
    if ( $borrower{branchcode} ) {
        unless ( GetBranchName( $borrower{branchcode} ) ) {
            push( @fail, 'branchcode' );
        }
    }
    return @fail;
}

sub _setDates {
    my $borrower = $_;
    my @fail;
    foreach (qw/dateofbirth dateenrolled dateexpiry/) {
        my $tempdate = $borrower{$_} or next;
        if ( $tempdate =~ /$date_re/ ) {
            $borrower{$_} = format_date_in_iso($tempdate);
        }
        elsif ( $tempdate =~ /$iso_re/ ) {
            $borrower{$_} = $tempdate;
        }
        else {
            # Ensure 'dateenrolled' is populated
            if ( $_ eq 'dateenrolled' ) {
                $borrower{$_} = $today_iso;
            }

            # Ensure 'dateexpiry' is populated
            elsif ( $_ eq 'dateexpiry' ) {
                $borrower{$_} = GetExpiryDate( $borrower{categorycode},
                    $borrower{dateenrolled} );
            }

            # Error
            else {
                $borrower{$_} = '';
                push( @fail, "$_" );
            }
        }
    }
    return @fail;
}

sub _setDefaults {
    my ( $borrower, $dbfields ) = @_;

    # On a per field basis, lookup rules.
    foreach my $csvfield ( keys %$borrower ) {

        # * Overwrite
        # Take CSV as definitive, overwrite DB)
        if ( $dbfields{$csvfield}{rule} == 'O' ) {

            # If zero non-whitespace characters are found,
            # we wish to wipe field
            if ( $borrower{$csvfield} !~ /\S/ ) {
                $borrower{$csvfield} = undef;
            }
        }

        # * Update
        # If CSV contains value, overwrite DB
        elsif ( $dbfields{$csvfield}{rule} == 'U' ) {

            # If zero non-whitespace characters are found,
            # we wish leave field as is
            if ( $borrower{$csvfield} !~ /\S/ ) {
                delete $borrower{$csvfield};
            }
        }

        # * Merge
        # Only add new values in CSV to DB.
        # Handled during import stage
        elsif ( $dbfields{$csvfield}{rule} == 'M' ) {
            next;
        }

        # * Reset
        # If CSV contains value, overwrite DB.
        # If CSV does not contain value, set to default
        else {

            # If zero non-whitespace characters are found,
            # we wish to set field with default values
            if ( $borrower{$csvfield} !~ /\S/ ) {
                $borrower{$csvfield} = $dbfields{$csvfield}{$default};
            }
        }
    }

    return 1;
}
