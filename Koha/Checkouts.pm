package Koha::Checkouts;

# Copyright ByWater Solutions 2015
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

use C4::Context;
use C4::Circulation qw( AddReturn );
use Koha::Checkout;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use base qw(Koha::Objects);

=head1 NAME

Koha::Checkouts - Koha Checkout object set class

=head1 API

=head2 Class Methods

=cut

=head3 calculate_dropbox_date

my $dt = Koha::Checkouts::calculate_dropbox_date();

=cut

sub calculate_dropbox_date {
    my $userenv    = C4::Context->userenv;
    my $branchcode = $userenv->{branch} // q{};

    my $daysmode = Koha::CirculationRules->get_effective_daysmode(
        {
            categorycode => undef,
            itemtype     => undef,
            branchcode   => $branchcode,
        }
    );
    my $calendar     = Koha::Calendar->new( branchcode => $branchcode, days_mode => $daysmode );
    my $today        = dt_from_string;
    my $dropbox_date = $calendar->addDuration( $today, -1 );

    return $dropbox_date;
}

=head3 automatic_checkin

my $automatic_checkins = Koha::Checkouts->automatic_checkin()

Checks in every due issue which itemtype has automatic_checkin enabled. Also if the AutoCheckinAutoFill system preference is enabled, the item is trapped for the next patron.

=cut

sub automatic_checkin {
    my ( $self, $params ) = @_;

    my $current_date = dt_from_string;

    my $dtf           = Koha::Database->new->schema->storage->datetime_parser;
    my $due_checkouts = $self->search(
        { date_due => { '<=' => $dtf->format_datetime($current_date) } },
        { prefetch => 'item' }
    );

    my $autofill_next = C4::Context->preference('AutomaticCheckinAutoFill');

    while ( my $checkout = $due_checkouts->next ) {
        if ( $checkout->item->itemtype->automatic_checkin ) {
            my ( undef, $messages ) = C4::Circulation::AddReturn(
                $checkout->item->barcode, $checkout->branchcode, undef,
                dt_from_string( $checkout->date_due )
            );
            if ($autofill_next) {
                if ( $messages->{ResFound} ) {
                    my $is_transfer = $checkout->branchcode ne $messages->{ResFound}->{branchcode};
                    C4::Reserves::ModReserveAffect(
                        $checkout->item->itemnumber, $checkout->borrowernumber,
                        $is_transfer, $messages->{ResFound}->{reserve_id}, $checkout->{desk_id}, 0
                    );
                    if ($is_transfer) {
                        C4::Items::ModItemTransfer(
                            $checkout->item->itemnumber,         $checkout->branchcode,
                            $messages->{ResFound}->{branchcode}, "Reserve"
                        );
                    }
                }
            }
        }
    }
}

=head3 type

=cut

sub _type {
    return 'Issue';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Checkout';
}

=head3 GetOverduesBy

my $overdues = Koha::Checkouts::GetOverdues( $parameters )

Fetches all overdues, and optionally filters by
- patron OR patron category  AND/OR  
- item home OR issue branch

=cut

# sub GetOverduesBy {
#     my ($parameters) = shift;

#     my %attributes;

#     # if ( $parameters->{get_summary} != 1 ) {
#     #     warn 'ran prefetch';
#     #     $attributes{prefetch} = {
#     #         'patron' => 'category',
#     #         'item'   => [ 'homebranch', { 'biblio' => 'biblioitem' } ]
#     #     };
#     # } else {
#     $attributes{join} = {
#         'patron' => 'category',
#         'item'   => [ 'homebranch', { 'biblio' => 'biblioitem' } ]
#     };

#     # $attributes{'+select'} = [
#     #     'borrowernumber',
#     #     'patron.firstname',
#     #     'patron.surname',
#     #     'patron.address',
#     #     'patron.address2',
#     #     'patron.city',
#     #     'patron.zipcode',
#     #     'patron.country',
#     #     'patron.email',
#     #     'patron.emailpro',
#     #     'patron.B_email',
#     #     'patron.smsalertnumber',
#     #     'patron.phone',
#     #     'patron.cardnumber',
#     #     'biblioitem.itemtype',
#     #     'homebranch.branchname',
#     #     'category.overduenoticerequired',
#     #     'item.homebranch',
#     # ];
#     # $attributes{'+as'} = [
#     #     'borrowernumber',
#     #     'patron_firstname',
#     #     'patron_surname',
#     #     'patron_address',
#     #     'patron_address2',
#     #     'patron_city',
#     #     'patron_zipcode',
#     #     'patron_country',
#     #     'patron_email',
#     #     'patron_emailpro',
#     #     'patron_B_email',
#     #     'patron_smsalertnumber',
#     #     'patron_phone',
#     #     'patron_cardnumber',
#     #     'biblioitem_itemtype',
#     #     'homebranch_branchname',
#     #     'category_overduenoticerequired',
#     #     'item_homebranch',
#     # ];
#     # }

#     # FILTERS:

#     my %conditions;

#     # is overdue
#     # FIXME: can be written as my $date = $parameters->{'date'} ?? dt_from_string() instead?
#     my $date = $parameters->{'date'} ? $parameters->{'date'} : dt_from_string();
#     $conditions{'item.itemlost'} = 0;
#     # FIXME: cannot seem to pass the below SQL functions as a condition to the DBI search() method
#     # -> impossible? -> moving back to using SQL instead
#     $conditions{"TO_DAYS($date)-TO_DAYS(issues.date_due)"} = { ">=", 0};

#     # patron (borrowernumber) or patron categorycode
#     if ( defined $parameters->{'borrowernumber'} ) {
#         $conditions{'me.borrowernumber'} = $parameters->{'borrowernumber'};
#     } elsif ( defined $parameters->{'patron_categorycode'} ) {
#         $conditions{'patron.categorycode'} = $parameters->{'patron_categorycode'};
#     }

#     # owning or issue branch
#     if ( defined $parameters->{'item_homebranch'} ) {
#         $conditions{'item.homebranch'} = $parameters->{'item_homebranch'};
#     } elsif ( defined $parameters->{'item_issuebranch'} ) {
#         $conditions{'issue.branchcode'} = $parameters->{'item_issuebranch'};
#     }

#     # item type, either at bib or item level
#     # my $itemtypes = join( ", ", Koha::ItemTypes->search()->get_column('itemtype') );
#     # if ( C4::Context->preference('item-level_itypes') ) {
#         # $conditions{'item.itype'} = { '-in', $itemtypes };
#     # } else {
#     #     $conditions{'biblioitem.itemtype'} = { '-in', $itemtypes };
#     # }

#     my $checkouts_set = Koha::Checkouts->new();

#     try {
#         # FIXME: does search
#         my $search_rs = $checkouts_set->search( \%conditions, \%attributes );
#         my @results;

#         # may want to leave this iteration in the script so we don't iterate twice
#         while ( my $row = $search_rs->next() ) {
#             push( @results, $row );
#         }
#         return @results;

#     } catch {
#         $checkouts_set->unhandled_exception($_);
#     };
# }

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;

# GetOverdues - alternative SQL version
sub GetOverduesBy {
    my ($parameters) = shift;

    my $dbh  = C4::Context->dbh();
    my $date = $parameters->{'date'} ? $parameters->{'date'} : 'NOW()';

    my $borrower_sql = <<"END_SQL";
SELECT
    issues.borrowernumber,
    borrowers.firstname,
    borrowers.surname,
    borrowers.address,
    borrowers.address2,
    borrowers.city,
    borrowers.zipcode,
    borrowers.country,
    borrowers.email,
    borrowers.emailpro,
    borrowers.B_email,
    borrowers.smsalertnumber,
    borrowers.phone,
    borrowers.cardnumber,
    borrowers.categorycode,
    biblio.*,
    biblioitems.itemtype AS b_itemtype,
    items.*,
    issues.*,
    branches.branchname,
    categories.overduenoticerequired
FROM
    issues
JOIN
    borrowers ON issues.borrowernumber = borrowers.borrowernumber
JOIN
    categories ON borrowers.categorycode = categories.categorycode
JOIN
    items ON issues.itemnumber = items.itemnumber
JOIN
    biblio ON biblio.biblionumber = items.biblionumber
JOIN
    biblioitems ON biblio.biblionumber = biblioitems.biblionumber
JOIN
    branches ON branches.branchcode = items.homebranch
WHERE
    items.itemlost = 0
    AND TO_DAYS($date)-TO_DAYS(issues.date_due) >= 0
END_SQL

    # conditions

    # owning or issue branch
    my @borrower_parameters;
    if ( $parameters->{'item_homebranch'} ) {
        $borrower_sql .= ' AND items.homebranch=? ';
        push @borrower_parameters, $parameters->{'item_homebranch'};
    } elsif ( $parameters->{'item_issuebranch'} ) {
        $borrower_sql .= ' AND issues.branchcode=? ';
        push @borrower_parameters, $parameters->{'item_issuebranch'};
    }

    # patron (borrowernumber) or patron categorycode
    if ( defined $parameters->{'borrowernumber'} ) {
        $borrower_sql .= ' AND borrowers.categorycode=? ';
        push @borrower_parameters, $parameters->{'patron_categorycode'};
    } elsif ( $parameters->{'patron_categorycode'} ) {
        $borrower_sql .= ' AND borrowers.categorycode=? ';
        push @borrower_parameters, $parameters->{'patron_categorycode'};
    }

    # item type, either at bib or item level
    my @itemtypes = Koha::ItemTypes->search()->get_column('itemtype');
    if (@itemtypes) {
        my $placeholders = join( ", ", ("?") x @itemtypes );
        if ( C4::Context->preference('item-level_itypes') ) {
            $borrower_sql .= " AND items.itype IN ($placeholders) ";
        } else {
            $borrower_sql .= " AND biblioitems.itemtype IN ($placeholders) ";
        }
        push @borrower_parameters, @itemtypes;
    }
    $borrower_sql .= '  ORDER BY issues.borrowernumber';

    # $sth gets borrower info if at least one overdue item has triggered the overdue action.
    my $sth = $dbh->prepare($borrower_sql);
    $sth->execute(@borrower_parameters);

    # leaving this in the script prevented duplicating iterations..
    my @results;
    while ( my $row = $sth->fetchrow_hashref ) {
        push( @results, $row );
    }
    return @results;
}
