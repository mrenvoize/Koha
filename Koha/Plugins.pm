package Koha::Plugins;

# Copyright 2012 Kyle Hall
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

use base qw(Koha::Objects);

use Koha::Plugin;

=head1 NAME

Koha::Plugins - Koha Plugin Object class, used to search for and load installed Koha Plugins.

=cut

=head2 METHODS

=head2 GetPlugins

This will return a list of all available plugins, optionally limited by
method or metadata value.

    my @plugins = Koha::Plugins::GetPlugins({
        method => 'some_method',
        metadata => { some_key => 'some_value' },
    });

The method and metadata parameters are optional.
Available methods currently are: 'report', 'tool', 'to_marc', 'edifact'.
If you pass multiple keys in the metadata hash, all keys must match.

=cut

sub GetPlugins {
    my ( $self, $params ) = @_;

    my $method       = $params->{method};
    my $req_metadata = $params->{metadata} // {};

    my $filter = ( $method ) ? { plugin_method => $method } : undef;

    my $rs =
        $method
      ? $self->search( { 'plugin_methods.plugin_method' => $method }, { join => 'plugin_methods' } )
      : $self->search( { enabled => 1 } );

    my @plugins = map { $_->load_plugin } $rs->as_list;
    return @plugins;
}

=head3 _type

=cut

sub _type {
    return 'Plugin';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Plugin';
}

=head1 AUTHORS

Kyle M Hall <kyle.m.hall@gmail.com>
Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut

1;
