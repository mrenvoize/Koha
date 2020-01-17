package Koha::Item::Transfer;

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

use Carp;

use C4::Items;

use Koha::Database;
use Koha::DateUtils;

use base qw(Koha::Object);

=head1 NAME

Koha::Item::Transfer - Koha Item Transfer Object class

=head1 API

=head2 Class Methods

=cut

=head3 transit

Set the transfer as in transit by updateing the datesent time.

Also, update date last seen and ensure item holdingbranch is correctly set.

=cut

sub transit {
    my ($self) = @_;

    # Throw exception if item is still checked out
    Koha::Exceptions::Transfer::Out->throw() if ($self->item->checkout);

    # Remove the 'shelving cart' location status if it is being used
    CartToShelf($self->item->itemnumber)
      if $self->item->location
      && $self->item->location eq 'CART'
      && ( !$self->item->permanent_location || $self->item->permanent_location ne 'CART' );

    # Update the transit state
    $self->set({ frombranch => $self->item->holdingbranch, datesent => dt_from_string, })->store;

    ModDateLastSeen($self->item->itemnumber);
    return $self;
}

=head3 type

=cut

sub _type {
    return 'Branchtransfer';
}

1;
