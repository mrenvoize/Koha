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

use Test::More tests => 18;
use Test::Warn;

use C4::Context;
use Koha::Database;
use Koha::DateUtils;

use t::lib::Dates;
use t::lib::TestBuilder;

BEGIN {
    use_ok('Koha::Objects');
    use_ok('Koha::Patrons');
}

# Start transaction
my $database = Koha::Database->new();
my $schema = $database->schema();
$schema->storage->txn_begin();
my $builder = t::lib::TestBuilder->new;

my $categorycode = $builder->build({ source => 'Category' })->{categorycode};
my $branchcode = $builder->build({ source => 'Branch' })->{branchcode};

my $b1 = Koha::Patron->new(
    {
        surname      => 'Test 1',
        branchcode   => $branchcode,
        categorycode => $categorycode
    }
);
$b1->store();
my $now = dt_from_string;
my $b2 = Koha::Patron->new(
    {
        surname      => 'Test 2',
        branchcode   => $branchcode,
        categorycode => $categorycode
    }
);
$b2->store();
my $three_days_ago = dt_from_string->add( days => -3 );
my $b3 = Koha::Patron->new(
    {
        surname      => 'Test 3',
        branchcode   => $branchcode,
        categorycode => $categorycode,
        updated_on   => $three_days_ago,
    }
);
$b3->store();

my $b1_new = Koha::Patrons->find( $b1->borrowernumber() );
is( $b1->surname(), $b1_new->surname(), "Found matching patron" );
isnt( $b1_new->updated_on, undef, "borrowers.updated_on should be set" );
is( t::lib::Dates::compare( $b1_new->updated_on, $now), 0, "borrowers.updated_on should have been set to now on creating" );

my $b3_new = Koha::Patrons->find( $b3->borrowernumber() );
is( t::lib::Dates::compare( $b3_new->updated_on, $three_days_ago), 0, "borrowers.updated_on should have been kept to what we set on creating" );
$b3_new->set({ firstname => 'Some first name for Test 3' })->store();
$b3_new = Koha::Patrons->find( $b3->borrowernumber() );
is( t::lib::Dates::compare( $b3_new->updated_on, $now), 0, "borrowers.updated_on should have been set to now on updating" );

my @patrons = Koha::Patrons->search( { branchcode => $branchcode } );
is( @patrons, 3, "Found 3 patrons with Search" );

my $unexistent = Koha::Patrons->find( '1234567890' );
is( $unexistent, undef, 'Koha::Objects->Find should return undef if the record does not exist' );

my $patrons = Koha::Patrons->search( { branchcode => $branchcode } );
is( $patrons->count( { branchcode => $branchcode } ), 3, "Counted 3 patrons with Count" );

my $b = $patrons->next();
is( $b->surname(), 'Test 1', "Next returns first patron" );
$b = $patrons->next();
is( $b->surname(), 'Test 2', "Next returns second patron" );
$b = $patrons->next();
is( $b->surname(), 'Test 3', "Next returns third patron" );
$b = $patrons->next();
is( $b, undef, "Next returns undef" );

# Test Reset and iteration in concert
$patrons->reset();
foreach my $b ( $patrons->as_list() ) {
    is( $b->categorycode(), $categorycode, "Iteration returns a patron object" );
}

subtest "Update patron categories" => sub {
    plan tests => 23;
    $builder->schema->resultset( 'Issue' )->delete_all;
    $builder->schema->resultset( 'Borrower' )->delete_all;
    $builder->schema->resultset( 'Category' )->delete_all;
    my $c_categorycode = $builder->build({ source => 'Category', value => {
            category_type=>'C',
            upperagelimit=>17,
            dateofbirthrequired=>5,
        } })->{categorycode};
    my $a_categorycode = $builder->build({ source => 'Category', value => {category_type=>'A'} })->{categorycode};
    my $p_categorycode = $builder->build({ source => 'Category', value => {category_type=>'P'} })->{categorycode};
    my $i_categorycode = $builder->build({ source => 'Category', value => {category_type=>'I'} })->{categorycode};
    my $branchcode1 = $builder->build({ source => 'Branch' })->{branchcode};
    my $branchcode2 = $builder->build({ source => 'Branch' })->{branchcode};
    my $adult1 = $builder->build({source => 'Borrower', value => {
            categorycode=>$a_categorycode,
            branchcode=>$branchcode1,
            dateenrolled=>'2018-01-01',
            sort1 =>'quack',
        }
    });
    my $adult2 = $builder->build({source => 'Borrower', value => {
            categorycode=>$a_categorycode,
            branchcode=>$branchcode2,
            dateenrolled=>'2017-01-01',
        }
    });
    my $inst = $builder->build({source => 'Borrower', value => {
            categorycode=>$i_categorycode,
            branchcode=>$branchcode2,
        }
    });
    my $prof = $builder->build({source => 'Borrower', value => {
            categorycode=>$p_categorycode,
            branchcode=>$branchcode2,
            guarantorid=>$inst->{borrowernumber},
        }
    });
    my $child1 = $builder->build({source => 'Borrower', value => {
            dateofbirth => dt_from_string->add(years=>-4),
            categorycode=>$c_categorycode,
            guarantorid=>$adult1->{borrowernumber},
            branchcode=>$branchcode1,
        }
    });
    my $child2 = $builder->build({source => 'Borrower', value => {
            dateofbirth => dt_from_string->add(years=>-8),
            categorycode=>$c_categorycode,
            guarantorid=>$adult1->{borrowernumber},
            branchcode=>$branchcode1,
        }
    });
    my $child3 = $builder->build({source => 'Borrower', value => {
            dateofbirth => dt_from_string->add(years=>-18),
            categorycode=>$c_categorycode,
            guarantorid=>$adult1->{borrowernumber},
            branchcode=>$branchcode1,
        }
    });
    $builder->build({source=>'Accountline',value => {amountoutstanding=>4.99,borrowernumber=>$adult1->{borrowernumber}}});
    $builder->build({source=>'Accountline',value => {amountoutstanding=>5.01,borrowernumber=>$adult2->{borrowernumber}}});

    is( Koha::Patrons->search_patrons_to_update({from=>$c_categorycode})->count,3,'Three patrons in child category');
    is( Koha::Patrons->search_patrons_to_update({from=>$c_categorycode,ageunder=>1})->count,1,'One under age patron in child category');
    is( Koha::Patrons->search_patrons_to_update({from=>$c_categorycode,ageunder=>1})->next->borrowernumber,$child1->{borrowernumber},'Under age patron in child category is expected one');
    is( Koha::Patrons->search_patrons_to_update({from=>$c_categorycode,ageover=>1})->count,1,'One over age patron in child category');
    is( Koha::Patrons->search_patrons_to_update({from=>$c_categorycode,ageover=>1})->next->borrowernumber,$child3->{borrowernumber},'Over age patron in child category is expected one');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{branchcode=>$branchcode2}})->count,1,'One patron in branch 2');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{branchcode=>$branchcode2}})->next->borrowernumber,$adult2->{borrowernumber},'Adult patron in branch 2 is expected one');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,fine_min=>5})->count,1,'One patron with fines over $5');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,fine_min=>5})->next->borrowernumber,$adult2->{borrowernumber},'One patron with fines over $5 is expected one');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,fine_max=>5})->count,1,'One patron with fines under $5');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,fine_max=>5})->next->borrowernumber,$adult1->{borrowernumber},'One patron with fines under $5 is expected one');

    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{dateenrolled=>{'<'=>'2018-01-01'}}})->count,1,'One adult patron enrolled before date');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{dateenrolled=>{'<'=>'2018-01-01'}}})->next->borrowernumber,$adult2->{borrowernumber},'One adult patron enrolled before date is expected one');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{dateenrolled=>{'>'=>'2017-01-01'}}})->count,1,'One adult patron enrolled after date');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{dateenrolled=>{'>'=>'2017-01-01'}}})->next->borrowernumber,$adult1->{borrowernumber},'One adult patron enrolled after date is expected one');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{'sort1'=>'quack'}})->count,1,'One adult patron has a quack');
    is( Koha::Patrons->search_patrons_to_update({from=>$a_categorycode,search_params=>{'sort1'=>'quack'}})->next->borrowernumber,$adult1->{borrowernumber},'One adult patron with a quack is expected one');

    is( Koha::Patrons->find($adult1->{borrowernumber})->guarantees->count,3,'Guarantor has 3 guarantees');
    is( Koha::Patrons->search_patrons_to_update({from=>$c_categorycode,ageunder=>1})->update_category({to=>$a_categorycode}),1,'One child patron updated to adult category');
    is( Koha::Patrons->find($adult1->{borrowernumber})->guarantees->count,2,'Guarantee was removed when made adult');

    is( Koha::Patrons->find($inst->{borrowernumber})->guarantees->count,1,'Guarantor has 1 guarantees');
    is( Koha::Patrons->search_patrons_to_update({from=>$p_categorycode})->update_category({to=>$a_categorycode}),1,'One professional patron updated to adult category');
    is( Koha::Patrons->find($inst->{borrowernumber})->guarantees->count,0,'Guarantee was removed when made adult');

};



$schema->storage->txn_rollback();

