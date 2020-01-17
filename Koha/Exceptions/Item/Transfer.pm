package Koha::Exceptions::Item::Transfer;

use Modern::Perl;

use Exception::Class (

    'Koha::Exceptions::Item::Transfer' => {
        description => 'Something went wrong'
    },
    'Koha::Exceptions::Item::Transfer::Found' => {
        isa => 'Koha::Exceptions::Item::Transfer',
        description => "Active item transfer already exists"
    },
    'Koha::Exceptions::Item::Transfer::Out' => {
        isa => 'Koha::Exceptions::Item::Transfer',
        description => "Transfer item is currently checked out"
    }

);

1;
