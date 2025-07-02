#!/usr/bin/perl

# TODO: determine which flags to allow if the script is run manually
# -> update the help menu accordingly
# -> update the code accordingly
# TODO: test and amend functionality for
#        - mark returned
#        - restrict
#        - notice (+ mtt)
#        - charge_cost
#      so far the focus has been on set_lost
# TODO: set and test sys prefs, amend accordingly

# Copyright 2008 Liblime
# Copyright 2010 BibLibre
#
# This file is part of Koha.
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

use Getopt::Long qw( GetOptions );
use Pod::Usage   qw( pod2usage );
use Text::CSV_XS;
use DateTime;
use DateTime::Duration;

use Koha::Script -cron;
use C4::Context;
use C4::Letters;
use C4::Overdues             qw( parse_overdues_letter );
use C4::Log                  qw( cronlogaction );
use Koha::Patron::Debarments qw( AddUniqueDebarment );
use Koha::DateUtils          qw( dt_from_string output_pref );
use Koha::Calendar;
use Koha::Libraries;
use Koha::Acquisition::Currencies;
use Koha::Patrons;

# added (absent from longoverdues.pl)
use C4::Circulation qw( LostItem MarkIssueReturned );
use Koha::Checkouts;

=head1 NAME

circulation_triggers.pl - prepare messages to be sent to patrons for overdue items

=head1 SYNOPSIS

circulation_triggers.pl
  [ -n ][ --library <branchcode> ][ --library <branchcode> ... ]
  [ --max <number of days> ][ --csv [<filename>] ][ --itemscontent <field list> ]
  [ --email <email_type> ... ]

 TODO: IDENTIFY WHICH TO KEEP -> update the multiple lists below accordingly
 Options:
   --help                          Brief help message.
   --man                           Full documentation.
   --verbose | -v                  Verbose mode. Can be repeated for increased output
   --nomail | -n                   No email will be sent.
   --max          <days>           Maximum days overdue to deal with.
   --library      <branchcode>     Only deal with overdues from this library.
                                   (repeatable : several libraries can be given)
   --csv          <filename>       Populate CSV file.
   --html         <directory>      Output html to a file in the given directory.
   --text         <directory>      Output plain text to a file in the given directory.
   --itemscontent <list of fields> Item information in templates.
   --borcat       <categorycode>   Category code that must be included.
   --borcatout    <categorycode>   Category code that must be excluded.
   --triggered | -t                Only include triggered overdues.
   --test                          Run in test mode. No changes will be made on the DB.
   --list-all                      List all overdues.
   --date         <yyyy-mm-dd>     Emulate overdues run for this date.
   --email        <email_type>     Type of email that will be used.
                                   Can be 'email', 'emailpro' or 'B_email'. Repeatable.
   --frombranch                    Organize and send overdue notices by home library (item-homebranch) or checkout library (item-issuebranch) or patron home library (patron-homebranch).
                                   This option is only used, if the OverdueNoticeFrom system preference is set to 'command-line option'.
                                   Defaults to item-issuebranch.

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<-v> | B<--verbose>

Verbose. Without this flag set, only fatal errors are reported.
A single 'v' will report info on branches, letter codes, and patrons.
A second 'v' will report The SQL code used to search for triggered patrons.

=item B<-n> | B<--nomail>

Do not send any email. Overdue notices that would have been sent to
the patrons or to the admin are printed to standard out. CSV data (if
the --csv flag is set) is written to standard out or to any csv
filename given.

=item B<--max>

Items older than max days are assumed to be handled somewhere else,
probably the F<longoverdues.pl> script. They are therefore ignored by
this program. No notices are sent for them, and they are not added to
any CSV files. Defaults to 90 to match F<longoverdues.pl>.

=item B<--library>

select overdues for one specific library. Use the value in the
branches.branchcode table. This option can be repeated in order
to select overdues for a group of libraries.

=item B<--csv>

Produces CSV data. if -n (no mail) flag is set, then this CSV data is
sent to standard out or to a filename if provided. Otherwise, only
overdues that could not be emailed are sent in CSV format to the admin.

=item B<--html>

Produces html data. If patron does not have an email address or
-n (no mail) flag is set, an HTML file is generated in the specified
directory. This can be downloaded or further processed by library staff.
The file will be called notices-YYYY-MM-DD.html and placed in the directory
specified.

=item B<--text>

Produces plain text data. If patron does not have an email address or
-n (no mail) flag is set, a text file is generated in the specified
directory. This can be downloaded or further processed by library staff.
The file will be called notices-YYYY-MM-DD.txt and placed in the directory
specified.

=item B<--itemscontent>

comma separated list of fields that get substituted into templates in
places of the E<lt>E<lt>items.contentE<gt>E<gt> placeholder. This
defaults to due date,title,barcode,author

Other possible values come from fields in the biblios, items and
issues tables.

=item B<--itemtypes>

Repeatable field, that permits to select only some item types.

=item B<--itemtypesout>

Repeatable field, that permits to exclude some item types.

=item B<--borcat>

Repeatable field, that permits to select only some patron categories.

=item B<--borcatout>

Repeatable field, that permits to exclude some patron categories.

=item B<-t> | B<--triggered>

This option causes a notice to be generated if and only if
an item is overdue by the number of days defined in a notice trigger.

By default, a notice is sent each time the script runs, which is suitable for
less frequent run cron script, but requires syncing notice triggers with
the  cron schedule to ensure proper behavior.
Add the --triggered option for daily cron, at the risk of no notice
being generated if the cron fails to run on time.

=item B<--test>

This option makes the script run in test mode.

In test mode, the script won't make any changes on the DB. This is useful
for debugging configuration.

=item B<--list-all>

Default items.content lists only those items that fall in the
range of the currently processing notice.
Choose --list-all to include all overdue items in the list (limited by B<--max> setting).

=item B<--date>

use it in order to send overdues on a specific date and not Now. Format: YYYY-MM-DD.

=item B<--email>

Allows to specify which type of email will be used. Can be email, emailpro or B_email. Repeatable.

=item B<--frombranch>

Organize overdue notices either by checkout library (item-issuebranch) or item home library (item-homebranch)  or patron home library (patron-homebranch).
This option is only used, if the OverdueNoticeFrom system preference is set to use 'command-line option'.
Defaults to checkout library (item-issuebranch).

=back

=head1 DESCRIPTION

This script is designed to alert patrons and administrators of overdue
items.

=head2 Configuration

This script pays attention to the overdue notice configuration
performed in the "Overdue notice/status triggers" section of the
"Tools" area of the staff interface to Koha. There, you can choose
which letter templates are sent out after a configurable number of
days to patrons of each library. More information about the use of this
section of Koha is available in the Koha manual.

The templates used to craft the emails are defined in the "Tools:
Notices" section of the staff interface to Koha.

=head2 Outgoing emails

Typically, messages are prepared for each patron with overdue
items. Messages for whom there is no email address on file are
collected and sent as attachments in a single email to each library
administrator, or if that is not set, then to the email address in the
C<KohaAdminEmailAddress> system preference.

These emails are staged in the outgoing message queue, as are messages
produced by other features of Koha. This message queue must be
processed regularly by the
F<misc/cronjobs/process_message_queue.pl> program.

In the event that the C<-n> flag is passed to this program, no emails
are sent. Instead, messages are sent on standard output from this
program. They may be redirected to a file if desired.

=head2 Templates

Templates can contain variables enclosed in double angle brackets like
<<this>>. Those variables will be replaced with values
specific to the overdue items or relevant patron. Available variables
are:

=over

=item E<lt>E<lt>bibE<gt>E<gt>

the name of the library

=item E<lt>E<lt>items.contentE<gt>E<gt>

one line for each item, each line containing a tab separated list of
title, author, barcode, issuedate

=item E<lt>E<lt>borrowers.*E<gt>E<gt>

any field from the borrowers table

=item E<lt>E<lt>branches.*E<gt>E<gt>

any field from the branches table

=back

=head2 CSV output

The C<-csv> command line option lets you specify a file to which
overdues data should be output in CSV format.

With the C<-n> flag set, data about all overdues is written to the
file. Without that flag, only information about overdues that were
unable to be sent directly to the patrons will be written. In other
words, this CSV file replaces the data that is typically sent to the
administrator email address.

=head1 USAGE EXAMPLES

C<circulation_triggers.pl> - In this most basic usage, with no command line
arguments, all libraries are processed individually, and notices are
prepared for all patrons with overdue items for whom we have email
addresses. Messages for those patrons for whom we have no email
address are sent in a single attachment to the library administrator's
email address, or to the address in the KohaAdminEmailAddress system
preference.

C<circulation_triggers.pl -n --csv /tmp/overdues.csv> - sends no email and
populates F</tmp/overdues.csv> with information about all overdue
items.

C<circulation_triggers.pl --library MAIN max 14> - prepare notices of
overdues in the last 2 weeks for the MAIN library.

=head1 SEE ALSO

The F<misc/cronjobs/advance_notices.pl> program allows you to send
messages to patrons in advance of their items becoming due, or to
alert them of items that have just become due.

=cut

# These variables are set by command line options.
# They are initially set to default values.
my $dbh         = C4::Context->dbh();
my $help        = 0;
my $man         = 0;
my $verbose     = 0;
my $nomail      = 0;
my $MAX         = 90;
my $test_mode   = 0;
my $frombranch  = 'item-issuebranch';
my $itype_level = C4::Context->preference('item-level_itypes') ? 'item' : 'biblioitem';
my @branchcodes;      # Branch(es) passed as parameter
my @emails_to_use;    # Emails to use for messaging
my @emails;           # Emails given in command-line parameters
my $csvfilename;
my $htmlfilename;
my $text_filename;
my $triggered    = 0;
my $listall      = 0;
my $itemscontent = join( ',', qw( date_due title barcode author itemnumber ) );
my @myitemtypes;
my @myitemtypesout;
my @myborcat;
my @myborcatout;

# TODO: also account for these circulation rules
my $set_lost;
my $charge_cost;
my $mark_returned;

my ( $date_input, $today );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

GetOptions(
    'help|?'         => \$help,
    'man'            => \$man,
    'v|verbose+'     => \$verbose,
    'n|nomail'       => \$nomail,
    'max=s'          => \$MAX,
    'csv:s'          => \$csvfilename,      # this optional argument gets '' if not supplied.
    'html:s'         => \$htmlfilename,     # this optional argument gets '' if not supplied.
    'text:s'         => \$text_filename,    # this optional argument gets '' if not supplied.
    'itemscontent=s' => \$itemscontent,
    'itemtypes=s'    => \@myitemtypes,
    'itemtypeouts=s' => \@myitemtypesout,
    'list-all'       => \$listall,
    't|triggered'    => \$triggered,
    'test'           => \$test_mode,
    'borcat=s'       => \@myborcat,
    'borcatout=s'    => \@myborcatout,
    'email=s'        => \@emails,
    'frombranch=s'   => \$frombranch,       # takes item-homebranch or item-issuebranch or patron-homebranch

    # ADDED - currently not implemented (only read values from relevant circ rules)
    'mark-returned'           => \$mark_returned,
    'set-lost-value'          => \$set_lost,        # was 'lost' in longoverdues
    'charge-replacement-cost' => \$charge_cost,
) or pod2usage(2);
pod2usage(1)               if $help;
pod2usage( -verbose => 2 ) if $man;

if ( defined $csvfilename && $csvfilename =~ /^-/ ) {
    warn qq(using "$csvfilename" as filename, that seems odd);
}

die "--frombranch takes item-homebranch or item-issuebranch or patron-homebranch only"
    unless ( $frombranch eq 'item-issuebranch'
    || $frombranch eq 'item-homebranch'
    || $frombranch eq 'patron-homebranch' );
$frombranch =
    C4::Context->preference('OverdueNoticeFrom') ne 'cron' ? C4::Context->preference('OverdueNoticeFrom') : $frombranch;
my $owning_library     = ( $frombranch eq 'item-homebranch' )   ? 1 : 0;
my $patron_homelibrary = ( $frombranch eq 'patron-homebranch' ) ? 1 : 0;

my @overduebranches = C4::Overdues::GetBranchcodesWithOverdueRules();  # Branches with overdue rules
my @branches;                                                          # Branches passed as parameter with overdue rules
my $branchcount = scalar(@overduebranches);

my $overduebranch_word = scalar @overduebranches > 1 ? 'branches' : 'branch';
my $branchcodes_word   = scalar @branchcodes > 1     ? 'branches' : 'branch';

my $PrintNoticesMaxLines = C4::Context->preference('PrintNoticesMaxLines');

if ($branchcount) {
    $verbose
        and warn "Found $branchcount $overduebranch_word with first message enabled: "
        . join( ', ', map { "'$_'" } @overduebranches ), "\n";
} else {
    $verbose and die 'No branches with active overduerules';
}

if (@branchcodes) {
    $verbose and warn "$branchcodes_word @branchcodes passed on parameter\n";

    # Getting libraries which have overdue rules
    my %seen = map { $_ => 1 } @branchcodes;
    @branches = grep { $seen{$_} } @overduebranches;

    if (@branches) {

        my $branch_word = scalar @branches > 1 ? 'branches' : 'branch';
        $verbose and warn "$branch_word @branches have overdue rules\n";

    } else {

        $verbose and warn "No active overduerules for $branchcodes_word  '@branchcodes'\n";
        ( scalar grep { '' eq $_ } @branches )
            or die "No active overduerules for DEFAULT either!";
        $verbose and warn "Falling back on default rules for @branchcodes\n";
        @branches = ('');
    }
}
my $date_to_run = dt_from_string();
my $date        = "NOW()";
if ($date_input) {
    eval { $date_to_run = dt_from_string( $date_input, 'iso' ); };
    die "$date_input is not a valid date, aborting! Use a date in format YYYY-MM-DD."
        if $@ or not $date_to_run;

    # It's certainly useless to escape $date_input
    # dt_from_string should not return something if $date_input is not correctly set.
    $date = $dbh->quote($date_input);
} else {
    $date        = "NOW()";
    $date_to_run = dt_from_string();
}

# these are the fields that will be substituted into <<item.content>>
my @item_content_fields = split( /,/, $itemscontent );

binmode( STDOUT, ':encoding(UTF-8)' );

our $csv;       # the Text::CSV_XS object
our $csv_fh;    # the filehandle to the CSV file.
if ( defined $csvfilename ) {
    my $sep_char = C4::Context->csv_delimiter;
    $csv = Text::CSV_XS->new( { binary => 1, sep_char => $sep_char, formula => "empty" } );
    if ( $csvfilename eq '' ) {
        $csv_fh = *STDOUT;
    } else {
        open $csv_fh, ">", $csvfilename or die "unable to open $csvfilename: $!";
    }
    if (
        $csv->combine(
            qw(name surname address1 address2 zipcode city country email phone cardnumber itemcount itemsinfo branchname letternumber)
        )
        )
    {
        print $csv_fh $csv->string, "\n";
    } else {
        $verbose and warn 'combine failed on argument: ' . $csv->error_input;
    }
}

@branches = @overduebranches unless @branches;

# Setup output file if requested
our $fh;
if ( defined $htmlfilename ) {
    if ( $htmlfilename eq '' ) {
        $fh = *STDOUT;
    } else {
        my $today = dt_from_string();
        open $fh, ">:encoding(UTF-8)", File::Spec->catdir( $htmlfilename, "notices-" . $today->ymd() . ".html" );
    }

    print $fh _get_html_start();
} elsif ( defined $text_filename ) {
    if ( $text_filename eq '' ) {
        $fh = *STDOUT;
    } else {
        my $today = dt_from_string();
        open $fh, ">:encoding(UTF-8)", File::Spec->catdir( $text_filename, "notices-" . $today->ymd() . ".txt" );
    }
}

# Setup category list
my @categories;
if (@myborcat) {
    @categories = @myborcat;
} elsif (@myborcatout) {
    @categories = Koha::Patron::Categories->search( { catagorycode => { 'not_in' => \@myborcatout } } )
        ->get_column('categorycode');
} else {
    @categories = Koha::Patron::Categories->search()->get_column('categorycode');
}

# Setup itemtype list
my @itemtypes;
if (@myitemtypes) {
    @itemtypes = @myitemtypes;
} elsif (@myitemtypesout) {
    @itemtypes =
        Koha::ItemTypes->search( { itemtype => { 'not_in' => \@myitemtypesout } } )->get_column('itemtype');
} else {
    @itemtypes = Koha::ItemTypes->search()->get_column('itemtype');
}

my %already_queued;
my %seen = map { $_ => 1 } @branches;

# # Work through branches
my @output_chunks;
foreach my $branchcode (@branches) {
    my $calendar;
    if ( C4::Context->preference('OverdueNoticeCalendar') ) {
        $calendar = Koha::Calendar->new( branchcode => $branchcode );
        if ( $calendar->is_holiday($date_to_run) ) {
            next;
        }
    }

    my $library              = Koha::Libraries->find($branchcode);
    my $admin_email_address  = $library->from_email_address;
    my $branch_email_address = C4::Context->preference('AddressForFailedOverdueNotices')
        || $library->inbound_email_address;

    $verbose and print "======================================\n";
    $verbose and warn sprintf "branchcode : '%s' using %s\n", $branchcode, $branch_email_address;

    # ========================================================
    # MOST CHANGES TO THE CODE FROM OVERDUENOTICES START HERE
    # ========================================================

    # TODO: check if the following sys pref needs accounting for
    # my $categories = C4::Context->preference('DefaultLongOverduePatronCategories');
    # if ( $categories ) {
    #     my $categories = $categories;
    #     $borrower_category = [ split( ',', $categories ) ];
    # } -> IRRELEVANT - we run this for categories

    for my $borrower_category (@categories) {
        my $parameters = {};
        $parameters->{item_homebranch}     = $branchcode;
        $parameters->{patron_categorycode} = $borrower_category;
        $parameters->{get_summary}         = 1;

        #FIXME: is there a better way to call GetOverduesBy?
        my @overdues = Koha::Checkouts::GetOverduesBy($parameters);

        my $borrowernumber;
        my $borrower_overdues_notices_triggers = {};

        foreach my $overdue (@overdues) {
            unless ( defined $borrower_overdues_notices_triggers->{borrowernumber} ) {
                if ($verbose) {
                    warn "\n-----------------------------------------\n";
                    warn "Collecting overdue triggers for borrower " . $overdue->{borrowernumber} . "\n";
                }
                $borrower_overdues_notices_triggers = {
                    borrowernumber => $overdue->{borrowernumber},
                    branchcode     => $branchcode
                };
            } elsif ( $borrower_overdues_notices_triggers->{borrowernumber} ne $overdue->{borrowernumber} ) {
                $verbose
                    and warn "Collected overdue triggers for "
                    . $borrower_overdues_notices_triggers->{borrowernumber} . "\n";
                _enact_notice_triggers_by_borrower($borrower_overdues_notices_triggers);
                if ($verbose) {
                    warn "\n-----------------------------------------\n";
                    warn "Collecting overdue triggers for borrower " . $overdue->{borrowernumber} . "\n";
                }
                $borrower_overdues_notices_triggers = {
                    borrowernumber => $overdue->{borrowernumber},
                    branchcode     => $branchcode
                };
            }

            my $itemtype = $overdue->{itype} // $overdue->{itemtype};

            # FIXME: not easily printed as the SQL was moved to Koha::Checkouts
            # -> do we need to find a way to achieve this?
            # if ( $verbose > 1 ) {
            #     warn sprintf "--------Borrower SQL------\n";
            #     warn $borrower_sql
            #         . "\n $branchcode | "
            #         . "'$borrower_category' | "
            #         . join( "','", @itemtypes ) . " | "
            #         . $date_to_run->datetime() . ")\n";
            #     warn sprintf "--------------------------\n";
            # }
            $verbose and warn sprintf "Found %s overdues for $borrower_category on $date_to_run\n", $overdue;

            $verbose
                and warn "\nProcessing overdue "
                . $overdue->{issue_id}
                . " with branch = '$branchcode', categorycode = '$borrower_category' and itemtype = '$itemtype'\n";

            # Work through triggers until we run out of rules or find a match
            _collect_or_enact_applicable_triggers(
                $borrower_overdues_notices_triggers,
                {
                    'borrower_category' => $borrower_category,
                    'branchcode'        => $branchcode,
                    'itemtype'          => $itemtype,
                    'overdue'           => $overdue,
                    'calendar'          => $calendar
                }
            );
        }

        # Catch final trigger
        unless ( $borrower_overdues_notices_triggers->{borrowernumber} ) {
            next;
        }

        # $verbose and warn "Collected overdue triggers for " . $borrower_overdues_notices_triggers->{borrowernumber} . "\n";
        _enact_notice_triggers_by_borrower($borrower_overdues_notices_triggers);
        $borrower_overdues_notices_triggers = {};
    }

    unless (@output_chunks) {
        next;
    }

    if ( defined $csvfilename ) {
        print $csv_fh @output_chunks;
    } elsif ( defined $htmlfilename ) {
        print $fh @output_chunks;
    } elsif ( defined $text_filename ) {
        print $fh @output_chunks;
    } elsif ($nomail) {
        local $, = "\f";    # pagebreak
        print @output_chunks;
    }

    # Generate the content of the csv with headers
    my $content;
    if ( defined $csvfilename ) {
        my $delimiter = C4::Context->csv_delimiter;
        $content = join(
            $delimiter,
            qw(title name surname address1 address2 zipcode city country email itemcount itemsinfo due_date issue_date)
        ) . "\n";
        $content .= join( "\n", @output_chunks );
    } elsif ( defined $htmlfilename ) {
        $content = _get_html_start();
        $content .= join( "\n", @output_chunks );
        $content .= _get_html_end();
    } else {
        $content = join( "\n", @output_chunks );
    }

    unless ( C4::Context->preference('EmailOverduesNoEmail') ) {
        next;
    }

    my $attachment = {
          filename => defined $csvfilename ? 'attachment.csv'
        : defined $htmlfilename ? 'attachment.html'
        : 'attachment.txt',
        type    => defined $htmlfilename ? 'text/html' : 'text/plain',
        content => $content,
    };

    my $letter = {
        title   => 'Overdue Notices',
        content => 'These messages were not sent directly to the patrons.',
    };

    C4::Letters::EnqueueLetter(
        {
            letter                 => $letter,
            borrowernumber         => undef,
            message_transport_type => 'email',
            attachments            => [$attachment],
            to_address             => $branch_email_address,
        }
    ) unless $test_mode;
}

if ($csvfilename) {

    # note that we're not testing on $csv_fh to prevent closing
    # STDOUT.
    close $csv_fh;
}

if ( defined $htmlfilename ) {
    print $fh _get_html_end();
    close $fh;
} elsif ( defined $text_filename ) {
    close $fh;
}

=head1 INTERNAL METHODS

These methods are internal to the operation of circulation_triggers.pl.

=cut

sub _collect_or_enact_applicable_triggers {
    my ($borrower_overdues_notices_triggers) = shift;
    my ($parameters)                         = shift;

    my $i = 0;
PERIOD: while (1) {
        $i++;
        my $ii = $i + 1;

        my $overdue_rules = Koha::CirculationRules->get_effective_rules(
            {
                rules => [
                    "overdue_$i" . '_delay',         "overdue_$i" . '_notice',   "overdue_$i" . '_mtt',
                    "overdue_$i" . '_restrict',      "overdue_$i" . '_set_lost', "overdue_$i" . '_charge_cost',
                    "overdue_$i" . '_mark_returned', "overdue_$ii" . '_delay'
                ],
                categorycode => $parameters->{'borrower_category'},
                branchcode   => $parameters->{'branchcode'},
                itemtype     => $parameters->{'itemtype'},
            }
        );

        # end of overdue array reached, stop iterating.s
        unless ( defined $overdue_rules->{ "overdue_$i" . '_delay' } ) {
            last PERIOD;
        }

        # check period compatibility
        my $mindays =
            $overdue_rules->{ "overdue_$i" . '_delay' };    # the notice will be sent after mindays days (grace period)
        my $maxdays = (
              $overdue_rules->{ "overdue_$ii" . '_delay' }
            ? $overdue_rules->{ "overdue_$ii" . '_delay' } - 1
            : ($MAX)
        );    # issues being more than maxdays late are managed somewhere else. (borrower probably suspended)

        my $days_between;
        if ( C4::Context->preference('OverdueNoticeCalendar') ) {
            $days_between = $parameters->{calendar}->days_between(
                dt_from_string( $parameters->{overdue}->{date_due} ),
                $date_to_run
            );
        } else {
            $days_between =
                $date_to_run->delta_days( dt_from_string( $parameters->{overdue}->{date_due} ) );
        }
        $days_between = $days_between->in_units('days');
        if ($listall) {
            unless ( $days_between >= 1 and $days_between <= $MAX ) {
                next;
            }
        } else {
            if ($triggered) {
                if ( $mindays != $days_between ) {
                    $verbose and warn "Overdue skipped for trigger $i\n";
                    next;
                }
            } else {
                unless ( $days_between >= $mindays
                    && $days_between <= $maxdays )
                {
                    $verbose and warn "Overdue skipped for trigger $i\n";
                    next;
                }
            }
        }

        # immediately enact relevant long overdue triggers
        my $set_lost = _get_set_lost_rule( $overdue_rules->{ "overdue_$i" . '_set_lost' } );
        if ( defined $set_lost ) {
            _enact_set_lost_trigger( $set_lost, $parameters->{overdue}->{itemnumber} );
        }

        my $charge_cost = _get_charge_cost_rule( $overdue_rules->{ "overdue_$i" . '_charge_cost' } );
        if ($charge_cost) {
            _enact_charge_cost_trigger( $charge_cost, $mark_returned, $parameters->{overdue}->{itemnumber} );
        }

        if ( $overdue_rules->{ "overdue_$i" . '_mark_returned' } ) {
            _enact_mark_returned_trigger(
                $parameters->{overdue}->{borrowernumber},
                $parameters->{overdue}->{itemnumber}
            );
        }

        if ( $overdue_rules->{ "overdue_$i" . '_restrict' } ) {
            _enact_restrict_trigger(
                {
                    borrowernumber => $parameters->{overdue}->{borrowernumber},
                    firstname      => $parameters->{overdue}->{firstname},
                    surname        => $parameters->{overdue}->{surname},
                }
            );
        }

        # notice triggers are to be enacted per letter, per transport type (and not per overdue).
        # -> add the notice triggers to the $borrower_overdues_notices_triggers hash so they may be processed later.
        if ( defined $overdue_rules->{ "overdue_$i" . '_notice' } ) {
            _add_notice_rule_to_borrower_overdues_notices_triggers(
                {
                    notice         => $overdue_rules->{ "overdue_$i" . '_notice' },
                    restrict       => $overdue_rules->{ "overdue_$i" . '_restrict' },
                    mtt            => $overdue_rules->{ "overdue_$i" . '_mtt' },
                    overdue        => $parameters->{overdue},
                    trigger_number => $i,
                },
                $borrower_overdues_notices_triggers
            );
        }

        if ($verbose) {
            my $borr = sprintf(
                "%s%s%s (%s)",
                $parameters->{overdue}->{surname} || '',
                $parameters->{overdue}->{firstname} && $parameters->{overdue}->{surname} ? ', ' : '',
                $parameters->{overdue}->{firstname} || '',
                $parameters->{overdue}->{borrowernumber}
            );
            warn sprintf "Overdue matched trigger %s with delay of %s days and overdue due date of %s\n",
                $i, $overdue_rules->{ "overdue_$i" . '_delay' }, $parameters->{overdue}->{date_due};
            warn sprintf "Using letter code '%s'\n",
                $overdue_rules->{ "overdue_$i" . '_notice' };
        }
    }
}

sub _get_set_lost_rule {
    my ($set_lost_rule) = @_;
    if ( defined $set_lost_rule ) {
        return $set_lost_rule;
    }
    my $longoverdue_value = C4::Context->preference('DefaultLongOverdueLostValue');
    my $longoverdue_days  = C4::Context->preference('DefaultLongOverdueDays');
    if (    defined($longoverdue_value)
        and defined($longoverdue_days)
        and $longoverdue_value ne ''
        and $longoverdue_days ne ''
        and $longoverdue_days >= 0 )
    {
        return $longoverdue_value;
    }
    return undef;
}

sub _get_charge_cost_rule {
    my ($charge_cost_rule) = @_;
    if ( defined $charge_cost_rule ) {
        return $charge_cost_rule;
    }
    return C4::Context->preference('DefaultLongOverdueChargeValue');
}

# sub _get_mark_returned_rule {
#     if ($mark_returned) {
#         return $mark_returned;
#     }
#     # TODO:check if sys pref or other to server as default?
#     # TODO:if not, simplify
#     return undef;
# }

# sub _get_restrict_rule {
#     if ($restrict) {
#         return $restrict;
#     }
#     # TODO:check if sys pref or other to server as default?
#     # TODO:if not, simplify
#     return undef;
# }

sub _enact_set_lost_trigger {
    my ( $set_lost, $itemnumber ) = @_;
    my $lost_item = Koha::Items->find($itemnumber);
    unless ( defined $lost_item ) {
        return;
    }
    $lost_item->itemlost($set_lost);
    $lost_item->store;
}

sub _enact_charge_cost_trigger {
    my ( $charge_cost, $mark_returned, $itemnumber ) = @_;
    LostItem(
        $itemnumber, 'cronjob', $mark_returned,
        $charge_cost
    );
}

sub _enact_mark_returned_trigger {
    my ( $borrowernumber, $itemnumber ) = @_;
    my $patron = Koha::Patrons->find($borrowernumber);
    MarkIssueReturned( $borrowernumber, $itemnumber, undef, $patron->privacy );
}

sub _enact_restrict_trigger {
    my ($borrower) = @_;
    AddUniqueDebarment(
        {
            borrowernumber => $borrower->{borrowernumber},
            type           => 'OVERDUES',
            comment        => "OVERDUES_PROCESS " . output_pref( dt_from_string() ),
        }
    ) unless $test_mode;

    my $borr = sprintf(
        "%s%s%s (%s)",
        $borrower->{surname} || '',
        $borrower->{firstname} && $borrower->{surname} ? ', ' : '',
        $borrower->{firstname} || '',
        $borrower->{borrowernumber}
    );
    $verbose and warn "debarring $borr\n";
}

sub _add_notice_rule_to_borrower_overdues_notices_triggers {
    my ( $parameters, $borrower_overdues_notices_triggers ) = @_;

    my @message_transport_types = split( /,/, $parameters->{mtt} );

    for my $mtt (@message_transport_types) {
        push @{ $borrower_overdues_notices_triggers->{triggers}->{ $parameters->{trigger_number} }
                ->{ $parameters->{notice} }->{$mtt} }, $parameters->{overdue};
    }
    if ( $parameters->{restrict} ) {
        $borrower_overdues_notices_triggers->{restrict} = 1;
    }
    $borrower_overdues_notices_triggers->{email}          = $parameters->{overdue}->{email};
    $borrower_overdues_notices_triggers->{emailpro}       = $parameters->{overdue}->{emailpro};
    $borrower_overdues_notices_triggers->{B_email}        = $parameters->{overdue}->{B_email};
    $borrower_overdues_notices_triggers->{smsalertnumber} = $parameters->{overdue}->{smsalertnumber};
    $borrower_overdues_notices_triggers->{phone}          = $parameters->{overdue}->{phone};
}

sub _enact_notice_triggers_by_borrower {
    my ($borrower_overdues_notices_triggers) = @_;

    my $borrowernumber = $borrower_overdues_notices_triggers->{borrowernumber};
    my $branchcode     = $borrower_overdues_notices_triggers->{branchcode};
    my $patron         = Koha::Patrons->find($borrowernumber);
    my ( $library, $admin_email_address, $branch_email_address );
    $library = Koha::Libraries->find($branchcode);

    if ($patron_homelibrary) {
        $branchcode           = $patron->branchcode;
        $library              = Koha::Libraries->find($branchcode);
        $admin_email_address  = $library->from_email_address;
        $branch_email_address = C4::Context->preference('AddressForFailedOverdueNotices')
            || $library->inbound_email_address;
    }
    @emails_to_use = ();
    my $notice_email = $patron->notice_email_address;
    unless ($nomail) {
        if (@emails) {
            foreach (@emails) {
                push @emails_to_use, $borrower_overdues_notices_triggers->{$_}
                    if ( $borrower_overdues_notices_triggers->{$_} );
            }
        } else {
            push @emails_to_use, $notice_email if ($notice_email);
        }
    }

    for my $trigger ( sort keys %{ $borrower_overdues_notices_triggers->{triggers} } ) {
        for my $notice ( keys %{ $borrower_overdues_notices_triggers->{triggers}->{$trigger} } ) {
            my $print_sent = 0;    # A print notice is not yet sent for this patron
            for my $mtt ( keys %{ $borrower_overdues_notices_triggers->{triggers}->{$trigger}->{$notice} } ) {

                next if $mtt eq 'itiva';
                my $effective_mtt = $mtt;
                if (   ( $mtt eq 'email' and not scalar @emails_to_use )
                    or ( $mtt eq 'sms' and not $borrower_overdues_notices_triggers->{smsalertnumber} ) )
                {
                    # email or sms is requested but not exist, do a print.
                    $effective_mtt = 'print';
                }

                my $j                            = 0;
                my $exceededPrintNoticesMaxLines = 0;

                # Get each overdue item for this trigger
                my $itemcount = 0;
                my $titles    = "";
                my @items     = ();
                for my $item_info (
                    @{ $borrower_overdues_notices_triggers->{triggers}->{$trigger}->{$notice}->{$effective_mtt} } )
                {
                    if (   ( scalar(@emails_to_use) == 0 || $nomail )
                        && $PrintNoticesMaxLines
                        && $j >= $PrintNoticesMaxLines )
                    {
                        $exceededPrintNoticesMaxLines = 1;
                        last;
                    }
                    next if $patron_homelibrary and !grep { $seen{ $item_info->{branchcode} } } @branches;
                    $j++;

                    $titles .= C4::Letters::get_item_content(
                        { item => $item_info, item_content_fields => \@item_content_fields, dateonly => 1 } );
                    $itemcount++;
                    push @items, $item_info;
                }

                splice @items, $PrintNoticesMaxLines
                    if $effective_mtt eq 'print'
                    && $PrintNoticesMaxLines
                    && scalar @items > $PrintNoticesMaxLines;

                #catch the case where we are sending a print to someone with an email

                my $letter_exists = Koha::Notice::Templates->find_effective_template(
                    {
                        module                 => 'circulation',
                        code                   => $notice,
                        message_transport_type => $effective_mtt,
                        branchcode             => $branchcode,
                        lang                   => $patron->lang
                    }
                );

                unless ($letter_exists) {
                    $verbose and warn qq|Message '$notice' for '$effective_mtt' content not found|;
                    next;
                }

                my $letter = parse_overdues_letter(
                    {
                        letter_code    => $notice,
                        borrowernumber => $borrowernumber,
                        branchcode     => $branchcode,
                        items          => \@items,
                        substitute     => {    # this appears to be a hack to overcome incomplete features in this code.
                            bib             => $library->branchname,    # maybe 'bib' is a typo for 'lib<rary>'?
                            'items.content' => $titles,
                            'count'         => $itemcount,
                        },

                        # If there is no template defined for the requested letter
                        # Fallback on the original type
                        message_transport_type => $letter_exists ? $effective_mtt : $mtt,
                    }
                );

                unless ( $letter && $letter->{content} ) {
                    $verbose and warn qq|Message '$notice' content not found|;

                    # this transport doesn't have a configured notice, so try another
                    next;
                }

                if ($exceededPrintNoticesMaxLines) {
                    $letter->{'content'} .=
                        "List too long for form; please check your account online for a complete list of your overdue items.";
                }

                my @misses = grep { /./ } map { /^([^>]*)[>]+/; ( $1 || '' ); } split /\</,
                    $letter->{'content'};
                if (@misses) {
                    $verbose
                        and warn "The following terms were not matched and replaced: \n\t" . join "\n\t",
                        @misses;
                }

                if ($nomail) {
                    push @output_chunks,
                        prepare_letter_for_printing(
                        {
                            letter         => $letter,
                            borrowernumber => $borrowernumber,
                            firstname      => $borrower_overdues_notices_triggers->{'firstname'},
                            lastname       => $borrower_overdues_notices_triggers->{'surname'},
                            address1       => $borrower_overdues_notices_triggers->{'address'},
                            address2       => $borrower_overdues_notices_triggers->{'address2'},
                            city           => $borrower_overdues_notices_triggers->{'city'},
                            phone          => $borrower_overdues_notices_triggers->{'phone'},
                            cardnumber     => $borrower_overdues_notices_triggers->{'cardnumber'},
                            branchname     => $library->branchname,
                            letternumber   => $trigger,
                            postcode       => $borrower_overdues_notices_triggers->{'zipcode'},
                            country        => $borrower_overdues_notices_triggers->{'country'},
                            email          => $notice_email,
                            itemcount      => $itemcount,
                            titles         => $titles,
                            outputformat   => defined $csvfilename ? 'csv'
                            : defined $htmlfilename  ? 'html'
                            : defined $text_filename ? 'text'
                            : '',
                        }
                        );
                    next;
                }

                if (   ( $mtt eq 'email' and not scalar @emails_to_use )
                    or ( $mtt eq 'sms' and not $borrower_overdues_notices_triggers->{smsalertnumber} ) )
                {
                    push @output_chunks,
                        prepare_letter_for_printing(
                        {
                            letter         => $letter,
                            borrowernumber => $borrowernumber,
                            firstname      => $borrower_overdues_notices_triggers->{'firstname'},
                            lastname       => $borrower_overdues_notices_triggers->{'surname'},
                            address1       => $borrower_overdues_notices_triggers->{'address'},
                            address2       => $borrower_overdues_notices_triggers->{'address2'},
                            city           => $borrower_overdues_notices_triggers->{'city'},
                            postcode       => $borrower_overdues_notices_triggers->{'zipcode'},
                            country        => $borrower_overdues_notices_triggers->{'country'},
                            email          => $notice_email,
                            itemcount      => $itemcount,
                            titles         => $titles,
                            outputformat   => defined $csvfilename ? 'csv'
                            : defined $htmlfilename  ? 'html'
                            : defined $text_filename ? 'text'
                            : '',
                        }
                        );
                }
                if ( $effective_mtt eq 'print' and $print_sent == 1 ) {
                    next;
                }

                # Just sent a print if not already done.
                C4::Letters::EnqueueLetter(
                    {
                        letter                 => $letter,
                        borrowernumber         => $borrowernumber,
                        message_transport_type => $effective_mtt,
                        from_address           => $admin_email_address,
                        to_address             => join( ',', @emails_to_use ),
                        reply_address          => $library->inbound_email_address,
                    }
                ) unless $test_mode;

                # A print notice should be sent only once per overdue level.
                # Without this check, a print could be sent twice or more if the library checks sms and email and print and the patron has no email or sms number.
                $print_sent = 1 if $effective_mtt eq 'print';
            }
            $already_queued{"$borrowernumber$trigger"} = 1;
        }
    }
}

=head2 prepare_letter_for_printing

returns a string of text appropriate for printing in the event that an
overdue notice will not be sent to the patron's email
address. Depending on the desired output format, this may be a CSV
string, or a human-readable representation of the notice.

required parameters:
  letter
  borrowernumber

optional parameters:
  outputformat

=cut

sub prepare_letter_for_printing {
    my $params = shift;

    return unless ref $params eq 'HASH';

    foreach my $required_parameter (qw( letter borrowernumber )) {
        return unless defined $params->{$required_parameter};
    }

    my $return;
    chomp $params->{titles};
    if ( exists $params->{'outputformat'} && $params->{'outputformat'} eq 'csv' ) {
        if (
            $csv->combine(
                $params->{'firstname'}, $params->{'lastname'}, $params->{'address1'}, $params->{'address2'},
                $params->{'postcode'},
                $params->{'city'}, $params->{'country'}, $params->{'email'}, $params->{'phone'},
                $params->{'cardnumber'},
                $params->{'itemcount'}, $params->{'titles'}, $params->{'branchname'}, $params->{'letternumber'}
            )
            )
        {
            return $csv->string, "\n";
        } else {
            $verbose and warn 'combine failed on argument: ' . $csv->error_input;
        }
    } elsif ( exists $params->{'outputformat'} && $params->{'outputformat'} eq 'html' ) {
        $return = "<pre>\n";
        $return .= "$params->{'letter'}->{'content'}\n";
        $return .= "\n</pre>\n";
    } else {
        $return .= "$params->{'letter'}->{'content'}\n";
    }
    return $return;
}

=head2 _get_html_start

Return the start of a HTML document, including html, head and the start body
tags. This should be usable both in the HTML file written to disc, and in the
attachment.html sent as email.

=cut

sub _get_html_start {
    return "<html>
<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
<style type='text/css'>
pre {page-break-after: always;}
pre {white-space: pre-wrap;}
pre {white-space: -moz-pre-wrap;}
pre {white-space: -o-pre-wrap;}
pre {word-wrap: break-work;}
</style>
</head>
<body>";

}

=head2 _get_html_end
Return the end of an HTML document, namely the closing body and html tags.
=cut

sub _get_html_end {
    return "</body>
</html>";
}

# =head2 skip_due_to_holiday
# Determines whether to skip notices or overdue actions due to holidays.
# =cut

# sub skip_due_to_holiday {
#     my ($branchcode) = @_;
#     my $calendar;
#     if ( C4::Context->preference('OverdueNoticeCalendar') ) {
#         $calendar = Koha::Calendar->new( branchcode => $branchcode );
#         if ( $calendar->is_holiday($date_to_run) ) {
#             return 1;
#         }
#     }
#     return 0;
# }

cronlogaction( { action => 'End', info => "COMPLETED" } );
