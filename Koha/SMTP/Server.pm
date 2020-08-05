package Koha::SMTP::Server;

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
use Koha::Exceptions::Object;
use Koha::SMTP::Servers;

use Email::Sender::Transport::SMTP;

use base qw(Koha::Object);

=head1 NAME

Koha::SMTP::Server - Koha SMTP Server Object class

=head1 API

=head2 Class methods

=head3 store

    my $server = Koha::SMTP::Server->new({...})->store;
    $server->set({...})->store;

Overloaded I<store> method that takes care of checking unicity of the
default server (i.e. when library_id IS NULL).

FIXME: Replace with a CHECK constraint when the feature is available.

=cut

sub store {
    my ( $self, $params ) = @_;

    if ( $self->in_storage ) {

        # update
        if ( !defined $self->library_id ) {

            # trying to set a default, check manually
            # until the DB can handle it
            Koha::Exceptions::Object::DuplicateID->throw( duplicate_id => 'library_id' )
              if Koha::SMTP::Servers->search(
                { library_id => undef, id => { '!=' => $self->id } } )->count > 0;
        }
    }
    else {
        # new
        if ( !defined $self->library_id ) {

            # trying to set a default, check manually
            # until the DB can handle it
            Koha::Exceptions::Object::DuplicateID->throw( duplicate_id => 'library_id' )
              if Koha::SMTP::Servers->search( { library_id => undef } )->count > 0;
        }
    }

    return $self->SUPER::store;
}

=head3 is_default

    my $is_default = $server->is_default

Helper method to determine if the server is the default one

=cut

sub is_default {
    my ($self) = @_;

    return (defined $self->library_id) ? 0 : 1;
}

=head3 library

Returns the Koha::Library object linked to the SMTP server.

=cut

sub library {
    my ( $self ) = @_;

    my $library_rs = $self->_result->library;
    return unless $library_rs;
    return Koha::Library->_new_from_dbic($self->_result->library);
}

=head3 transport

    my $transport = $smtp_server->transport;
    sendmail( $message, { transport => $transport } );

Returns an I<Email::Sender::Transport::SMTP> object that can be used directly
with Email::Sender.

=cut

sub transport {
    my ($self) = @_;

    my $params = {
        host => $self->host,
        port => $self->port,
    };

    $params->{ssl} = $self->ssl_mode
        unless $self->ssl_mode eq 'disabled';

    $params->{timeout} = $self->timeout
        if $self->timeout;

    $params->{sasl_username} = $self->user_name
        if $self->user_name;

    $params->{sasl_password} = $self->password
        if $self->password;


    my $transport = Email::Sender::Transport::SMTP->new( $params );

    return $transport;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::SMTP::Server object
on the API.

=cut

sub to_api_mapping {
    return {
        id => 'smtp_server_id'
    };
}

=head2 Internal methods

=head3 _type

Return type of Object relating to Schema ResultSet

=cut

sub _type {
    return 'SmtpServer';
}

1;
