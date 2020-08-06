package Koha::Email;

# Copyright 2014 Catalyst
#           2020 Theke Solutions
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

use Email::Valid;
use Email::MessageID;

use C4::Context;

use base qw( Email::Stuffer );

=head1 NAME

Koha::Email - A wrapper around Email::Stuffer

=head1 API

=head2 Class methods

=head3 create

    my $email = Koha::Email->create(
        {
          [ text_body   => $text_message,
            html_body   => $html_message, ]
            from        => $from,
            to          => $to,
            cc          => $cc,
            bcc         => $bcc,
            replyto     => $replyto,
            sender      => $sender,
            subject     => $subject,
            charset     => $charset,
        }
    );

This method creates a new Email::Simple object taking Koha specific configurations
into account.

Parameters:
 - I<from> defaults to the value of the I<KohaAdminEmailAddress> system preference
 - I<charset> defaults to B<utf8>
 - The I<SendAllEmailsTo> system preference overloads the I<to>, I<cc> and I<bcc> parameters
 - I<replyto> defaults to the value of the I<ReplytoDefault> system preference
 - I<sender> defaults to the value of the I<ReturnpathDefault> system preference

=cut

sub create {
    my ( $self, $params ) = @_;

    my $from    = $params->{from}    // C4::Context->preference('KohaAdminEmailAddress');
    my $charset = $params->{charset} // 'utf8';
    my $subject = $params->{subject} // '';

    my $args = {
        from    => $from,
        subject => $subject,
    };

    $params->{replyto} ||= C4::Context->preference('ReplytoDefault')
        if C4::Context->preference('ReplytoDefault');

    $params->{sender} ||= C4::Context->preference('ReturnpathDefault')
        if C4::Context->preference('ReturnpathDefault') ;


    if (   C4::Context->preference('SendAllEmailsTo')
        && Email::Valid->address( C4::Context->preference('SendAllEmailsTo') ) )
    {
        $args->{to} = C4::Context->preference('SendAllEmailsTo');
    }
    else {
        $args->{to}  = $params->{to};
        $args->{cc}  = $params->{cc}
            if exists $params->{cc};
        $args->{bcc} = $params->{bcc}
            if exists $params->{bcc};
    }

    my $email = $self->SUPER::new( $args );

    $email->header( 'ReplyTo', $params->{replyto} )
        if $params->{replyto};

    $email->header( 'charset'      => $charset );
    $email->header( 'Sender'       => $params->{sender} );
    $email->header( 'Content-Type' => $params->{contenttype} ) if $params->{contenttype};
    $email->header( 'X-Mailer'     => "Koha" );
    $email->header( 'Message-ID'   => Email::MessageID->new->in_brackets );

    if ( $params->{text_body} ) {
        $email->text_body( $params->{text_body} );
    }
    elsif ( $params->{html_body} ) {
        $email->html_body( $params->{html_body} );
    }

    return $email;
}

1;
