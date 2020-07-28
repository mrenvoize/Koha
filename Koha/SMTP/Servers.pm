package Koha::SMTP::Servers;

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

use Koha::Database;
use Koha::Exceptions;

use Koha::SMTP::Server;

use base qw(Koha::Objects);

=head1 NAME

Koha::SMTP::Servers - Koha SMTP Server Object set class

=head1 API

=head2 Class methods

=head3 get_effective_server

    my $server = Koha::SMTP::Servers->get_effective_server({ library => $library });

Returns a I<Koha::SMTP::Server> representing the effective configured SMTP for the library.

=cut

sub get_effective_server {
    my ($self, $args) = @_;

    my $library = $args->{library};

    Koha::Exceptions::MissingParameter->throw('Mandatory parameter missing: library')
        unless $library;

    my $servers_rs = Koha::SMTP::Servers->search({ library_id => $library->branchcode });
    if ( $servers_rs->count > 0 ) {
        return $servers_rs->next;
    }

    return $self->get_default;
}

=head3 get_default

    my $server = Koha::SMTP::Servers->new->get_default;

Returns the default I<Koha::SMTP::Server> object.

=cut

sub get_default {
    my ($self) = @_;

    my $servers_rs = $self->search({ library_id => undef });

    my $server;
    if ($servers_rs->count > 0) {
        $server = $servers_rs->next;
    }
    else {
        $server = Koha::SMTP::Server->new( $self->default_setting );
    }

    return $server;
}

=head3 set_default

    my $server = Koha::SMTP::Servers->new->set_default;

Set the default I<Koha::SMTP::Server> server, and returns it.

=cut

sub set_default {
    my ($self, $params) = @_;

    Koha::Exceptions::BadParameter->throw( 'library_id must be undef when setting the default SMTP server' )
        if defined $params->{library_id};

    my $smtp_server;
    $self->_resultset()->result_source->schema->txn_do( sub {

        # Delete existing default
        $self->search({ library_id => undef })->delete;

       $smtp_server = Koha::SMTP::Server->new($params)->store;
    });

    return $smtp_server;
}

=head3 set_library_server

    my $server = Koha::SMTP::Servers->new->set_library_server(
        {
            name       => $name,
            library_id => $library->id,
            host       => $smtp_host,
            port       => $smtp_port,
            timeout    => $smtp_timeout,
            ssl        => 1,
            user_name  => $user_name,
            password   => $password
        }
    );

Set the I<Koha::SMTP::Server> server for a library, and return it.

=cut

sub set_library_server {
    my ( $self, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw(
        'Mandatory parameter missing: library_id')
      unless $params->{library_id};

    my $smtp_server;
    $self->_resultset()->result_source->schema->txn_do( sub {
        # Delete existing default
        $self->search({ library_id => $params->{library_id} })->delete;

        $smtp_server = Koha::SMTP::Server->new($params)->store;
    });

    return $smtp_server;
}

=head2 Internal methods

=head3 _type

Return type of object, relating to Schema ResultSet

=cut

sub _type {
    return 'SmtpServer';
}

=head3 default_setting

    my $hash = Koha::SMTP::Servers::default_setting;

Returns the default setting that is to be used when no user-defined default
SMTP server is provided

=cut

sub default_setting {
    return {
        name       => 'localhost',
        library_id => undef,
        host       => 'localhost',
        port       => 25,
        timeout    => 120,
        ssl_mode  => 'disabled',
        user_name  => undef,
        password   => undef,
        debug      => 0
    };
}

=head3 object_class

Return object class

=cut

sub object_class {
    return 'Koha::SMTP::Server';
}

1;
