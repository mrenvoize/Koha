#!/usr/bin/env perl

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

use threads;

use Modern::Perl;
use File::Temp;
use File::Tail;
use JSON;
use YAML::Any qw/LoadFile/;
use Pod::Usage;

=head1 NAME

import_borrowers - This script is a command line access point to the staff client patron import utility

=cut

use Carp qw(cluck carp croak confess);
use Getopt::Long;
use Koha::Borrowers::Import qw/importBorrowers/;

my ( $help, $verbose, $matchpoint, $infile, $defualtsfile, $logfilename,
    $email )
    = ( '', '1', 'cardnumber', '', '' );
GetOptions(
    'h|help'         => \$help,
    'v|verbose!+'    => \$verbose,
    'matchpoint'     => \$matchpoint,
    'infile=s'       => \$infile,
    'defualtsfile:s' => \$defaultsfile,

    'email:s'   => \$email,
    'logfile:s' => \$logfilename,
) || pod2usage(1);

if ($help) {
    pod2usage(1);
}

# Get a handle for our input
if ($infile) {
    open( INFILE, "<$infile" ) || croak "Cannot open input file: $!\n";
    $inputfile = *INFILE;
}
else {    # default to reading from standard input
    $inputfile = *STDIN;
}

# Parse the defaults file, the defaults file should be of a yaml format
my $defaults;
if ($defaultsfile) {
    $defaults = LoadFile($defaultsfile)
        || croak "Cannot open defaults file: $!\n";
}

# Can we store a standard defaults set in the database for fallback?
# Should we do another level of fallback should the database set no exist?
else {

}

# Set shared report file
unless ($logfilename) {
    my $logfile = File::Temp->new();
    $logfilename = $logfile->filename;
}

# Now push the magic button (Spawn off one thread to do import and another thread to monitor progress/errors)
my $processor = threads->create(
    Koha::Borrowers::Import::importBorrowers(
        $inputfile, \%defaults, $matchpoint, $logfilename
    )
)->join();
my $reporter = threads->create( reportProgress($logfilename) )->join();

my %retval = $processor->join();
close($inputfile);

# Now print out informational messages if requested (from retval)
if ($verbose) {
    foreach my $f (@$feedback) {
        printf "* %s: %s\n", $f->{name}, $f->{value};
    }
    printf "\n";
    printf "Successful imports: %d\n", $retval{imported};
    printf "Record overwrites: %d\n",  $retval{overwritten};
    printf "Not overwritten: %d\n",    $retval{alreadyindb};
    printf "Bogus entries: %d\n",      $retval{invalid};
}

# exit success if no errors, otherwise failure
exit( @$errors != 0 );

sub reportProgress {
    my $filename = shift;

    my $report = File::Tail->new(
        name        => $filename,
        maxinterval => 300,
        adjustafter => 7
    );
    while ( defined( $json = $report->read ) ) {
        my $reportline = $json->decode($json);
        print Dumper $reportline;
    }
}

# Redundant - Using pod2usage!
sub usage {
    printf <<END;
Usage: import_borrowers.pl [options]
Options:
  --infile=<filename>       : read data from filename instead of stdin
  --defaultsfile=<filename> : read defaults from filename
  --matchpoint=<string>     : match for collisions on this field
  --overwrite               : overwrite collisions with new values
  --email                   : email address to send logs to
  --verbose                 : be noisier
  --logfile:<string>        : location for permanent logs (optional)

  --help                    : show this message
END
}

=head1 SYNOPSIS

import_borrowers.pl [-h|--help] [-v|--verbose] [-c|--confirm] [--not_borrowed_since=DATE] [--expired_before=DATE] [--category_code=CAT] [--library=LIBRARY]

Dates should be in ISO format, e.g., 2013-07-19, and can be generated
with `date -d '-3 month' "+%Y-%m-%d"`.

The options to select the patron records to delete are cumulative.  For
example, supplying both --expired_before and --library specifies that
that patron records must meet both conditions to be selected for deletion.

=head1 OPTIONS

=over

=item B<-h|--help>

Print a brief help message

=item B<--not_borrowed_since>

Delete patrons who have not borrowed since this date.

=item B<--expired_before>

Delete patrons with an account expired before this date.

=item B<--category_code>

Delete patrons who have this category code.

=item B<--library>

Delete patrons in this library.

=item B<-c|--confirm>

This flag must be provided in order for the script to actually
delete patron records.  If it is not supplied, the script will
only report on the patron records it would have deleted.

=item B<-v|--verbose>

Verbose mode.

=back

=head1 AUTHOR

Jonathan Druart <jonathan.druart@biblibre.com>

=head1 COPYRIGHT

Copyright 2013 BibLibre

=head1 LICENSE

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later version.

You should have received a copy of the GNU General Public License along
with Koha; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=cut
