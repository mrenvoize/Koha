package C4::Auth_with_Shibboleth;

# Copyright 2011 BibLibre
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use C4::Debug;
use C4::Context;
use Carp;
use CGI;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $debug);

BEGIN {
    require Exporter;
    $VERSION = 3.03;                                                                    # set the version for version checking
    $debug   = $ENV{DEBUG};
    @ISA     = qw(Exporter);
    @EXPORT  = qw(logout_shib login_shib_url checkpw_shib get_login_shib);
}
my $context = C4::Context->new() or die 'C4::Context->new failed';
my $protocol = "https://";

# Logout from Shibboleth
sub logout_shib {
    my ($query) = @_;
    my $uri = $protocol . C4::Context->preference('OPACBaseURL');
    print $query->redirect( $uri . "/Shibboleth.sso/Logout?return=$uri" );
}

# Returns Shibboleth login URL with callback to the requesting URL
sub login_shib_url {

    my ($query) = @_;
    my $param = $protocol . C4::Context->preference('OPACBaseURL') . $query->script_name();
    if ( $query->query_string() ) {
        $param = $param . '%3F' . $query->query_string();
    }
    my $uri = $protocol . C4::Context->preference('OPACBaseURL') . "/Shibboleth.sso/Login?target=$param";
    return $uri;
}

# Returns shibboleth user login
sub get_login_shib {

    # In case of a Shibboleth authentication, we expect a shibboleth user attribute (defined in the shibbolethLoginAttribute)
    # to contain the login of the shibboleth-authenticated user

    # Shibboleth attributes are mapped into http environmement variables,
    # so we're getting the login of the user this way

    my $shib = C4::Context->config('shibboleth') or croak 'No <shibboleth> in koha-conf.xml';

    my $shibbolethLoginAttribute = $shib->{'userid'};
    $debug and warn "shibboleth->userid value: $shibbolethLoginAttribute";
    $debug and warn "$shibbolethLoginAttribute value: " . $ENV{$shibbolethLoginAttribute};

    return $ENV{$shibbolethLoginAttribute} || '';
}

# Checks for password correctness
# In our case : does the given username matches one of our users ?
sub checkpw_shib {
    $debug and warn "checkpw_shib";

    my ( $dbh, $userid ) = @_;
    my $retnumber;
    $debug and warn "User Shibboleth-authenticated as: $userid";

    my $shib = C4::Context->config('shibboleth') or croak 'No <shibboleth> in koha-conf.xml';

    # Does it match one of our users ?
    my $sth = $dbh->prepare("select cardnumber from borrowers where userid=?");
    $sth->execute($userid);
    if ( $sth->rows ) {
        $retnumber = $sth->fetchrow;
        return ( 1, $retnumber, $userid );
    }
    $sth = $dbh->prepare("select userid from borrowers where cardnumber=?");
    $sth->execute($userid);
    if ( $sth->rows ) {
        $retnumber = $sth->fetchrow;
        return ( 1, $retnumber, $userid );
    }

    # If we reach this point, the user is not a valid koha user
    $debug and warn "User $userid is not a valid Koha user";
    return 0;
}

1;
__END__

=head1 NAME

C4::Auth_with_shibboleth

=head1 SYNOPSIS

use C4::Auth_with_shibboleth

=head1 DESCRIPTION

This module is specific to Shibboleth authentication in koha and relies heavily upon the native shibboleth service provider package in your operating system.

=head1 CONFIGURATION

To use this type of authentication these additional packages are required:

=over

=item *

libapache2-mod-shib2

=item *

libshibsp5:amd64

=item *

shibboleth-sp2-schemas

=back

We let the native shibboleth service provider packages handle all the complexities of shibboleth negotiation for use and configuring this is beyond the scope of this documentation; But to sum up, you will need to:

=over

=item 1.

Create some metadata for your koha instance (if you're in a single instance setup then the default metadata available at https://youraddress.com/Shibboleth.sso/Metadata should be adequate)

=item 2.

Swap metadata with your Identidy Provider (IdP)

=item 3.

Map their attributes to what you want to see in koha

=item 4.

Tell apache that we wish to allow koha to authenticate via shibboleth; This is as simple as adding the below to your virtualhost config:

=begin text

<Location />
  AuthType shibboleth
  Require shibboleth
</Location>

=end text

=item 5.

Configure koha to listen for shibboleth environment variables; To do this we add <useshibboleth>1</useshibboleth> for the koha-conf.xml file

=item 6.

Map shibboleth attributes to koha fields in koha-conf.xml.

<shibboleth>
  <mapping>
    <userid match="1" default="">eduPersonID</userid>
    <categorycode default=""></categorycode>
  </mapping>
</shibboleth>

=back

=head1 FUNCTIONS

=cut
