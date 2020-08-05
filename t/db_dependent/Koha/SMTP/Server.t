#!/usr/bin/perl

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

use Test::More tests => 3;
use Test::Exception;
use Test::Warn;

use Koha::SMTP::Servers;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'is_default() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    Koha::SMTP::Servers->search->delete;

    my $default_server = $builder->build_object(
        {
            class => 'Koha::SMTP::Servers',
            value => {
                library_id => undef
            }
        }
    );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_specific_server = $builder->build_object(
        {
            class => 'Koha::SMTP::Servers',
            value => {
                library_id => $library->branchcode
            }
        }
    );

    ok( $default_server->is_default, 'Server is the default one' );
    ok( !$library_specific_server->is_default,
        'Server is not the default one' );

    $schema->storage->txn_rollback;
};

subtest 'store() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    Koha::SMTP::Servers->search->delete;

    my $default_server = Koha::SMTP::Server->new(
        {
            library_id => undef,
            name       => 'Default SMTP server'
        }
    )->store;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_specific_server = Koha::SMTP::Server->new(
        {
            library_id => $library->id,
            name       => 'Library-specific SMTP server'
        }
    )->store;

    warning_like
        {
            throws_ok
                { Koha::SMTP::Server->new(
                    {
                        library_id => $library->id,
                        name       => 'Some fake name'
                    }
                )->store; }
                'Koha::Exceptions::Object::DuplicateID',
                'Cannot define two servers for the same library';
        }
        qr/DBI Exception: DBD::mysql::st execute failed: Duplicate entry/,
        'Warning is printed';

    throws_ok
        { Koha::SMTP::Server->new(
            {
                library_id => undef,
                name       => 'Some fake name'
            }
        )->store; }
        'Koha::Exceptions::Object::DuplicateID',
        'Cannot define two default SMTP servers';

    $default_server->set({ name => 'New name' })->store;
    $default_server->discard_changes;

    is( $default_server->name, 'New name', 'Default server updated correctly' );

    $schema->storage->txn_rollback;
};

subtest 'transport() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $server = $builder->build_object(
        {
            class => 'Koha::SMTP::Servers',
            value => { ssl_mode => 'disabled' }
        }
    );

    my $transport = $server->transport;

    is( ref($transport), 'Email::Sender::Transport::SMTP', 'Type is correct' );
    is( $transport->ssl, 0, 'SSL is not set' );

    $server->set({ ssl_mode => 'ssl' })->store;
    $transport = $server->transport;

    is( ref($transport), 'Email::Sender::Transport::SMTP', 'Type is correct' );
    is( $transport->ssl, 'ssl', 'SSL is set' );

    $schema->storage->txn_rollback;
};
