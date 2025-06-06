use Test::More;
use lib::abs 'lib';
use uni::perl ':dumper';
use GPBExim::TestHelper qw(test_search test_live_search cq);


test_search("Search for email 'fwxvparobkymnbyemevz\@london.com' with bounce" => join("\n",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded",
  "2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO Completed"),
  "fwxvparobkymnbyemevz\@london.com" => {render=> 'JSON', data=>[{
    t => "log", o_id => 2, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
    str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded",
  }]},
);

test_search("Search for email 'london.com' with bounce" =>join("\n",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded",
  "2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO Completed"),
  'london.com' => {render=> 'JSON', data=>
  [
    {
      t => "log", o_id => 1, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
      str => "1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}"
    },
    {
      t => "log", o_id => 2, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
      str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded"
    },
  ]},
);

test_live_search("Search for email 'fwxvparobkymnbyemevz\@london.com' with bounce" => join("\n",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded",
  "2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO Completed"),
  "fwxvparobkymnbyemevz\@london.com" => {render=> 'JSON', data=>[{
    t => "log", o_id => 2, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
    str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded",
  }]},
);

test_live_search("Search for email 'london.com' with bounce" =>join("\n",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded",
  "2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958",
  "2012-02-13 14:39:22 1RookS-000Pg8-VO Completed"),
  'london.com' => {render=> 'JSON', data=>
  [
    {
      t => "log", o_id => 1, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
      str => "1RookS-000Pg8-VO == udbbwscdnbegrmloghuf\@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf\@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}"
    },
    {
      t => "log", o_id => 2, int_id => "1RookS-000Pg8-VO", created => '2012-02-13 14:39:22',
      str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded"
    },
  ]},
);

done_testing;