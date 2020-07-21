#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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
use CGI qw ( -utf8 );

use C4::Context;
use C4::Output;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Koha;
use Koha::BiblioFrameworks;
use Koha::Cash::Registers;
use Koha::Libraries;

my $query = CGI->new();

my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user({
    template_name   => "circ/set-library.tt",
    query           => $query,
    type            => "intranet",
    debug           => 1,
    authnotrequired => 0,
    flagsrequired   => { catalogue => 1, },
});

my $sessionID = $query->cookie("CGISESSID");
my $session = get_session($sessionID);

my $branch              = $query->param('branch');
my $register_id         = $query->param('register_id');
my $userenv_branch      = C4::Context->userenv->{'branch'} || '';
my $userenv_register_id = C4::Context->userenv->{'register_id'} || '';
my @updated;

# $session lines here are doing the updating
if ( $branch and my $library = Koha::Libraries->find($branch) ) {
    if (! $userenv_branch or $userenv_branch ne $branch ) {
        my $branchname = $library->branchname;
        $template->param(LoginBranchname => $branchname);   # update template for new branch
        $template->param(LoginBranchcode => $branch);       # update template for new branch
        $session->param('branchname', $branchname);         # update sesssion in DB
        $session->param('branch', $branch);                 # update sesssion in DB
        push @updated, {
            updated_branch => 1,
                old_branch => $userenv_branch,
        };
    } # else branch the same, no update
    if ( defined($userenv_register_id)
        && ( $userenv_register_id ne $register_id ) )
    {
        my $register = Koha::Cash::Registers->find($register_id);
        $template->param(LoginRegisterID   => $register_id);   # update template for new register
        $template->param(LoginRegisterName   => $register ? $register->name : '');   # update template for new register
        $session->param( 'register_id', $register_id );
        push @updated,
          {
            updated_register => 1,
            new_register     => $register ? $register->name : ''
          };
    }
    $session->flush();
} else {
    $branch = $userenv_branch;  # fallback value
}

$template->param(updated => \@updated) if (scalar @updated);

my @recycle_loop;
foreach ( $query->param() ) {
    $_ or next;    # disclude blanks
    $_ eq "branch"      and next;    # disclude branch
    $_ eq "register_id" and next;    # disclude register
    $_ eq "oldreferer"  and next;    # disclude oldreferer
    push @recycle_loop,
      {
        param => $_,
        value => scalar $query->param($_),
      };
}

my $referer =  $query->param('oldreferer') || $ENV{HTTP_REFERER};
$referer =~ /set-library\.pl/ and undef $referer;   # avoid sending them back to this same page.

if (scalar @updated and not scalar @recycle_loop) {
    # we updated something, and there were no extra params to POST: quick redirect
    print $query->redirect($referer || '/cgi-bin/koha/circ/circulation.pl');
}

$template->param(
    referer     => $referer,
    branch      => $branch,
    recycle_loop=> \@recycle_loop,
);

# Checking if there is a Fast Cataloging Framework
$template->param( fast_cataloging => 1 ) if Koha::BiblioFrameworks->find( 'FA' );

output_html_with_http_headers $query, $cookie, $template->output;
