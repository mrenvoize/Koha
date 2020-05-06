package Koha::Plugins::Installer;

# Copyright 2020 Martin Renvoize
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

use Class::Inspector;
use List::MoreUtils qw(any);
use Module::Load qw(load);
use Module::Load::Conditional qw(can_load);
use Module::Pluggable search_path => ['Koha::Plugin'], except => qr/::Edifact(|::Line|::Message|::Order|::Segment|::Transport)$/;
use YAML qw(Load Dump);

use Koha::DateUtils;
use Koha::Plugins::Data;
use Koha::Plugins::Methods;

our @pluginsdir;

BEGIN {
    my $pluginsdir = C4::Context->config("pluginsdir");
    @pluginsdir = ref($pluginsdir) eq 'ARRAY' ? @$pluginsdir : $pluginsdir;
    push( @INC, @pluginsdir );
    pop @INC if $INC[-1] eq '.';
}

=head1 NAME

Koha::Plugins::Installer - Module for installing plugins.

=cut

sub new {
    my ( $class, $args ) = @_;

    return unless ( C4::Context->config("enable_plugins") || $args->{'enable_plugins'} );

    $args->{'pluginsdir'} = C4::Context->config("pluginsdir");

    return bless( $args, $class );
}

=head2 refresh

    Koha::Plugins::Installer->refresh()

This method iterates through all plugins physically present on a system.
For each plugin module found, it will test that the plugin can be loaded,
and if it can, will store its available methods in the plugin_methods table.

NOTE: We re-load all plugins here as a protective measure in case someone
has removed a plugin directly from the system without using the UI

=cut

sub refresh {
    my ( $self, $params ) = @_;

    my @plugin_classes = $self->plugins();

    foreach my $plugin_class (@plugin_classes) {
        if ( can_load( modules => { $plugin_class => undef }, nocache => 1 ) ) {
            next unless $plugin_class->isa('Koha::Plugins::Base');

            my $plugin = $plugin_class->new({ enable_plugins => $self->{enable_plugins} });

            # Update plugin metadata from PLUGIN.yml
            my $metadata = $plugin->get_metadata();
            my $record = Koha::Plugins->find($plugin_class)
              || Koha::Plugin->new( { class => $plugin_class } );
            $record->set(
                {
                    name          => $metadata->{name} // $plugin_class,
                    version       => $metadata->{version} // 0,
                    date_updated  => dt_from_string,
                    author        => $metadata->{author},
                    date_authored => $metadata->{date_authored},
                    min_koha      => $metadata->{min_koha},
                    max_koha      => $metadata->{max_koha},
                    description   => $metadata->{description}
                }
            );
            $record->store;

            # Update methods list from Plugin
            Koha::Plugins::Methods->search({ plugin_class => $plugin_class })->delete();

            foreach my $method ( @{ Class::Inspector->methods( $plugin_class, 'public' ) } ) {
                Koha::Plugins::Method->new(
                    {
                        plugin_class  => $plugin_class,
                        plugin_method => $method,
                    }
                )->store();
            }

        } else {
            my $error = $Module::Load::Conditional::ERROR;
            # Do not warn the error if the plugin has been uninstalled
            warn $error unless $error =~ m|^Could not find or check module '$plugin_class'|;
        }
    }

    return Koha::Plugins->search();
}

1;
__END__

=head1 AUTHOR

Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut
