use utf8;
package Koha::Schema::Result::SmtpServer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::SmtpServer

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<smtp_servers>

=cut

__PACKAGE__->table("smtp_servers");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 library_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=head2 host

  data_type: 'varchar'
  default_value: 'localhost'
  is_nullable: 0
  size: 80

=head2 port

  data_type: 'integer'
  default_value: 25
  is_nullable: 0

=head2 timeout

  data_type: 'integer'
  default_value: 120
  is_nullable: 0

=head2 ssl_mode

  data_type: 'enum'
  extra: {list => ["disabled","ssl","starttls"]}
  is_nullable: 0

=head2 user_name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 password

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 debug

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "library_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "host",
  {
    data_type => "varchar",
    default_value => "localhost",
    is_nullable => 0,
    size => 80,
  },
  "port",
  { data_type => "integer", default_value => 25, is_nullable => 0 },
  "timeout",
  { data_type => "integer", default_value => 120, is_nullable => 0 },
  "ssl_mode",
  {
    data_type => "enum",
    extra => { list => ["disabled", "ssl", "starttls"] },
    is_nullable => 0,
  },
  "user_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "debug",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<library_id_idx>

=over 4

=item * L</library_id>

=back

=cut

__PACKAGE__->add_unique_constraint("library_id_idx", ["library_id"]);

=head1 RELATIONS

=head2 library

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "library",
  "Koha::Schema::Result::Branch",
  { branchcode => "library_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2020-08-07 17:39:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:J3/OstCVck+dZe54w/Xkxw

__PACKAGE__->add_columns(
    '+debug' => { is_boolean => 1 }
);

sub koha_objects_class {
    'Koha::SMTP::Servers';
}

sub koha_object_class {
    'Koha::SMTP::Server';
}

1;
