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

use Test::More tests => 2;

use t::lib::Mocks;

use_ok('Koha::Email');

subtest 'create() tests' => sub {

    plan tests => 21;

    t::lib::Mocks::mock_preference( 'SendAllEmailsTo', undef );

    my $html_body = '<h1>Title</h1><p>Message</p>';
    my $text_body = "#Title: Message";

    my $email = Koha::Email->create(
        {
            from      => 'from@example.com',
            charset   => 'iso-8859-1',
            to        => 'to@example.com',
            cc        => 'cc@example.com',
            bcc       => 'bcc@example.com',
            replyto   => 'replyto@example.com',
            sender    => 'sender@example.com',
            subject   => 'Some subject',
            html_body => $html_body,
        }
    );

    is( $email->email->header('From'), 'from@example.com', 'Value set correctly' );
    is( $email->email->header('charset'), 'iso-8859-1', 'Value set correctly' );
    is( $email->email->header('To'), 'to@example.com', 'Value set correctly' );
    is( $email->email->header('Cc'), 'cc@example.com', 'Value set correctly' );
    is( $email->email->header('Bcc'), 'bcc@example.com', 'Value set correctly' );
    is( $email->email->header('ReplyTo'), 'replyto@example.com', 'Value set correctly' );
    is( $email->email->header('Sender'), 'sender@example.com', 'Value set correctly' );
    is( $email->email->header('Subject'), 'Some subject', 'Value set correctly' );
    is( $email->email->header('X-Mailer'), 'Koha', 'Value set correctly' );
    is( $email->email->body, $html_body, "Body set correctly" );
    is( $email->email->content_type, 'text/html; charset="utf-8"', "Content type set correctly");
    like( $email->email->header('Message-ID'), qr/\<.*@.*\>/, 'Value set correctly' );

    t::lib::Mocks::mock_preference( 'SendAllEmailsTo', 'catchall@example.com' );
    t::lib::Mocks::mock_preference( 'ReplytoDefault', 'replytodefault@example.com' );
    t::lib::Mocks::mock_preference( 'ReturnpathDefault', 'returnpathdefault@example.com' );
    t::lib::Mocks::mock_preference( 'KohaAdminEmailAddress', 'kohaadminemailaddress@example.com' );

    $email = Koha::Email->create(
        {
            to        => 'to@example.com',
            cc        => 'cc@example.com',
            bcc       => 'bcc@example.com',
            text_body => $text_body,
        }
    );

    is( $email->email->header('From'), 'kohaadminemailaddress@example.com', 'KohaAdminEmailAddress is picked when no from passed' );
    is( $email->email->header('charset'), 'utf8', 'utf8 is the default' );
    is( $email->email->header('To'), 'catchall@example.com', 'SendAllEmailsTo overloads any address' );
    is( $email->email->header('Cc'), undef, 'SendAllEmailsTo overloads any address' );
    is( $email->email->header('Bcc'), undef, 'SendAllEmailsTo overloads any address' );
    is( $email->email->header('ReplyTo'), 'replytodefault@example.com', 'ReplytoDefault picked when replyto not passed' );
    is( $email->email->header('Sender'), 'returnpathdefault@example.com', 'ReturnpathDefault picked when sender not passed' );
    is( $email->email->body, $text_body, "Body set correctly" );
    is( $email->email->content_type, 'text/plain; charset="utf-8"; format="flowed"', "Content type set correctly");
};
