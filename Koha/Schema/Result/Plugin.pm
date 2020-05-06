use utf8;
package Koha::Schema::Result::Plugin;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Plugin

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<plugins>

=cut

__PACKAGE__->table("plugins");

=head1 ACCESSORS

=head2 class

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 name

  data_type: 'mediumtext'
  is_nullable: 1

=head2 version

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 date_installed

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 date_updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 author

  data_type: 'mediumtext'
  is_nullable: 1

=head2 date_authored

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 min_koha

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 max_koha

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 description

  data_type: 'mediumtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "class",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "name",
  { data_type => "mediumtext", is_nullable => 1 },
  "version",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "date_installed",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "date_updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "author",
  { data_type => "mediumtext", is_nullable => 1 },
  "date_authored",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "min_koha",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "max_koha",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "description",
  { data_type => "mediumtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</class>

=back

=cut

__PACKAGE__->set_primary_key("class");

=head1 RELATIONS

=head2 plugin_methods

Type: has_many

Related object: L<Koha::Schema::Result::PluginMethod>

=cut

__PACKAGE__->has_many(
  "plugin_methods",
  "Koha::Schema::Result::PluginMethod",
  { "foreign.plugin_class" => "self.class" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2020-05-06 12:55:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TRB0sYjSmhTbKYVk5o0YWg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
