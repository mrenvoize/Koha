use utf8;
package Koha::Schema::Result::PluginMethod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::PluginMethod

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<plugin_methods>

=cut

__PACKAGE__->table("plugin_methods");

=head1 ACCESSORS

=head2 plugin_class

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 191

=head2 plugin_method

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "plugin_class",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 191 },
  "plugin_method",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 RELATIONS

=head2 plugin_class

Type: belongs_to

Related object: L<Koha::Schema::Result::Plugin>

=cut

__PACKAGE__->belongs_to(
  "plugin_class",
  "Koha::Schema::Result::Plugin",
  { class => "plugin_class" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2020-05-06 12:55:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LkE7uqY3Vmtobbv+Djvfmw

sub koha_objects_class {
    'Koha::Plugins::Methods';
}
sub koha_object_class {
    'Koha::Plugins::Method';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
