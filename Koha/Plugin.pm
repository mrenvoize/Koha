package Koha::Plugin;

# Copyright PTFS Europe 2020
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

use Module::Load qw(load);

use base qw(Koha::Object);

=head2 Methods

=head3 load_plugin

    my $loaded = $plugin->load_plugin;
    $loaded->$method();

Returns the loaded plugin ready to take action.

=cut

sub load_plugin {
    my ($self) = @_;

    my $class = $self->class;
    load $class;

    my $plugin = $class->new();
    return unless $plugin->is_enabled;
    return $plugin;
}

=head3 methods

    my $methods = $plugin->methods

Return the list of methods available for this plugin

=cut

sub methods {
    my ( $self ) = @_;
    my $rs = $self->_result->plugin_methods;
    return unless $rs;
    return Koha::Plugin::Methods->_new_from_dbic($rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Plugin';
}

=head1 AUTHORS

Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut

1;
