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
use JSON::XS;

sub cq {
  my %search = @_;

  my $req = HTTP::Request->new(POST => '/search');
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json({ s => "$search{created} $search{email}" }));

  return $req;
}

my $m = GPBExim::get_model('SQLite3::Memory'); $m->setup_schema();
my $v = GPBExim::View->new(model => $m);
my $c = GPBExim::Controller->new();

my $domain = 'london.com';
my %search; %search = (email => "fwxvparobkymnbyemevz\@$domain", created => '2012-02-13 14:39:22');

$c->parse_chunk($m => join(' ',
  qq{$search{created} 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@$domain},
  qq{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@$domain>:},
  q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
  q{( http://portal.gmx.net/serverrules ) {mx-us011}})
  ."\n"
  ."$search{created} 1RookS-000Pg8-VO ** $search{email}: retry timeout exceeded\n"
  ."$search{created} 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958\n"
  ."$search{created} 1RookS-000Pg8-VO Completed"
);


is_deeply( $v->handle_request(cq(%search)), { data => [
  {
    t => "log", o_id => 2,
    int_id => "1RookS-000Pg8-VO",
    created => $search{created},
    str => "1RookS-000Pg8-VO ** $search{email}: retry timeout exceeded",
  },
  {
    t => "message_bounce", o_id => 3,
    int_id => "1RwtJa-000AFJ-3B",
    created => $search{created},
    str => "1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958",
  }
] }, "Search for email '$search{email}' with bounce");

is_deeply( $v->handle_request(cq(%search, email => $domain)), { data => [
    {
      t => "log", o_id => 1,
      int_id => "1RookS-000Pg8-VO",
      created => $search{created},
      str => "1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@$domain R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@$domain>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}"
    },
    {
      t => "log", o_id => 2,
      int_id => "1RookS-000Pg8-VO",
      created => $search{created},
      str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@$domain: retry timeout exceeded"
    },
    {
      t => "message_bounce", o_id => 3,
      int_id => "1RwtJa-000AFJ-3B",
      created => $search{created},
      str => "1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958",
    }
  ] }, "Search for part of email - domain '$domain' with bounce");

done_testing;

