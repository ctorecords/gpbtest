use Test::More;
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim::Test qw(test_search cq);

my $domain = 'london.com';
my $search; $search="fwxvparobkymnbyemevz\@$domain";

test_search("Search for email '$search' with bounce" =>
  join(' ',
    qq{2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@$domain},
    qq{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@$domain>:},
    q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
    q{( http://portal.gmx.net/serverrules ) {mx-us011}}
  )."\n"
  ."2012-02-13 14:39:22 1RookS-000Pg8-VO ** $search: retry timeout exceeded\n"
  ."2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958\n"
  ."2012-02-13 14:39:22 1RookS-000Pg8-VO Completed",
  $search => {data=>[{
    t => "log", o_id => 2, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
    str => "1RookS-000Pg8-VO ** $search: retry timeout exceeded",
  }]},
  rm_xapian_db_on_destroy => 1,
  rm_xapian_db_on_init => 1,
);

test_search("Search for email '$domain' with bounce" =>
  join(' ',
    qq{2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@$domain},
    qq{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@$domain>:},
    q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
    q{( http://portal.gmx.net/serverrules ) {mx-us011}}
  )."\n"
  ."2012-02-13 14:39:22 1RookS-000Pg8-VO ** $search: retry timeout exceeded\n"
  ."2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958\n"
  ."2012-02-13 14:39:22 1RookS-000Pg8-VO Completed",
  $domain => {data=>[
  {
    t => "log", o_id => 1, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
    str => "1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@$domain R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@$domain>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}"
  },
  {
    t => "log", o_id => 2, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
    str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@$domain: retry timeout exceeded"
  },
  ]},
  rm_xapian_db_on_destroy => 1,
  rm_xapian_db_on_init => 1,
);


done_testing;