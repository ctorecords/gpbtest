use strict;
use warnings;
use Test::More;
use lib::abs '../lib';
use uni::perl ':dumper';
use Try::Tiny;
use GPBExim;
use GPBExim::View;
use GPBExim::Controller;
use HTTP::Request;

my $controller = GPBExim::Controller->new();
my $model = GPBExim::get_model('SQLite3::Memory'); $model->setup_schema();

$controller->parse_chunk($model => join(' ',
        q{2012-02-13 14:39:22},
        q{1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com},
        q{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>:},
        q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
        q{( http://portal.gmx.net/serverrules ) {mx-us011}})
        . "\n" .
        q{2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz@london.com: retry timeout exceeded}
        . "\n" .
        q{2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958}
        . "\n" .
        q{2012-02-13 14:39:22 1RookS-000Pg8-VO Completed}
);

my $view = GPBExim::View->new(model => $model);
my $r = HTTP::Request->new(GET => '/');
is_deeply($view->handle_request($r), {
  data => {
    message_address => 2,
    bounce_reasons => 0,
    message => 0,
    log => 3,
    message_bounce => 1
  }
}, 'Sample view test');
done_testing;

