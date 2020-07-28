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

use Test::More tests => 4;
use Test::Exception;

use Koha::SMTP::Servers;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'get_default() tests' => sub {

    plan tests => 3;

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

    my $servers = Koha::SMTP::Servers->new;
    my $server  = $servers->get_default;
    is( $server->id, $default_server->id,
        'The default server is correctly retrieved' );

    # Delete the default server
    $server->delete;

    # Get the default
    $default_server = $servers->get_default;
    is( ref($default_server), 'Koha::SMTP::Server',
        'An object of the right type is returned' );

    my $unblessed_server = $default_server->unblessed;
    delete $unblessed_server->{id};
    is_deeply(
        $unblessed_server,
        Koha::SMTP::Servers::default_setting,
        'The default setting is returned if no user-defined default'
    );

    $schema->storage->txn_rollback;
};

subtest 'set_default() tests' => sub {

    plan tests => 4;

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

    throws_ok {
        Koha::SMTP::Servers->new->set_default(
            {
                name       => 'A new default',
                library_id => 'Whatever',
            }
        );
    }
    'Koha::Exceptions::BadParameter',
'Exception thrown when trying to set default SMTP server with a library_id';

    is(
        "$@",
        'library_id must be undef when setting the default SMTP server',
        'Exception message is clear'
    );

    my $new_default = Koha::SMTP::Servers->new->set_default(
        {
            name       => 'A new default',
            library_id => undef,
        }
    );

    is( ref($new_default), 'Koha::SMTP::Server', 'Type is correct' );
    is(
        $new_default->id,
        Koha::SMTP::Servers->get_default->id,
        'Default SMTP server is correctly set'
    );

    $schema->storage->txn_rollback;
};

subtest 'get_effective_server() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    Koha::SMTP::Servers->search->delete;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $default_server = $builder->build_object(
        {
            class => 'Koha::SMTP::Servers',
            value => {
                library_id => undef
            }
        }
    );

    throws_ok { Koha::SMTP::Servers->new->get_effective_server() }
    'Koha::Exceptions::MissingParameter', 'Exception thrown';

    is( "$@", 'Mandatory parameter missing: library' );

    is(
        Koha::SMTP::Servers->new->get_effective_server(
            { library => $library }
        )->id,
        $default_server->id,
        'Fallback default server retrieved'
    );

    my $specific_server = $builder->build_object(
        {
            class => 'Koha::SMTP::Servers',
            value => {
                library_id => $library->branchcode
            }
        }
    );

    is(
        Koha::SMTP::Servers->new->get_effective_server(
            { library => $library }
        )->id,
        $specific_server->id,
        'Library specific server retrieved'
    );

    $schema->storage->txn_rollback;
};

subtest 'set_library_server() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    Koha::SMTP::Servers->search->delete;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $default_server = $builder->build_object(
        {
            class => 'Koha::SMTP::Servers',
            value => {
                library_id => undef
            }
        }
    );

    is(
        Koha::SMTP::Servers->new->get_effective_server(
            { library => $library }
        )->id,
        $default_server->id,
        'Fallback default server retrieved'
    );

    my $specific_server = Koha::SMTP::Servers->new->set_library_server(
        {
            name       => 'Specific server 1',
            library_id => $library->id
        }
    );

    is(
        Koha::SMTP::Servers->new->get_effective_server(
            { library => $library }
        )->id,
        $specific_server->id,
        'Library specific server retrieved'
    );

    throws_ok {
        Koha::SMTP::Servers->new->set_library_server(
            {
                name => 'Specific server 2'
            }
        );
    }
    'Koha::Exceptions::MissingParameter',
      'Exception thrown on missing parameter';

    is( "$@", 'Mandatory parameter missing: library_id' );

    $specific_server = Koha::SMTP::Servers->new->set_library_server(
        {
            name       => 'Specific server 2',
            library_id => $library->id
        }
    );

    is(
        Koha::SMTP::Servers->new->get_effective_server(
            { library => $library }
        )->id,
        $specific_server->id,
        'New library specific server retrieved'
    );

    is( Koha::SMTP::Servers->search( { library_id => $library->id } )->count,
        1, 'Only one SMTP server set' );

    $schema->storage->txn_rollback;
};
