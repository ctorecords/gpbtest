use Test::More;
use lib::abs 'lib';
use uni::perl ':dumper';
use GPBExim::TestHelper qw(test_search test_live_search cq);


test_search(q{Search for email 'lqkwrzreonkhhtql\@terraoil.ru' without bounce} => join("\n",
    '2012-02-13 14:59:56 1RwtdJ-0000Ac-Ch == lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set',
    '2012-02-13 15:02:02 1RwtdJ-0000Ac-Ch ** lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp: SMTP error from remote mail server after RCPT TO:<lqkwrzreonkhhtql@terraoil.ru>: host mail-s56.1gb.ru [81.177.159.3]: 553 We do not relay without RFC2554 authentication.',
    '2012-02-13 15:02:02 1RwtfW-000LYI-8j <= <> R=1RwtdJ-0000Ac-Ch U=mailnull P=local S=3509',
  ),
  'lqkwrzreonkhhtql@terraoil.ru' => {
      render=> 'JSON',
      data=>[
        { int_id => "1RwtdJ-0000Ac-Ch", o_id => 1, t => "log", created => "2012-02-13 14:59:56", str => '1RwtdJ-0000Ac-Ch == lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set' },
        { int_id => "1RwtdJ-0000Ac-Ch", o_id => 2, t => "log", created => "2012-02-13 15:02:02", str => '1RwtdJ-0000Ac-Ch ** lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp: SMTP error from remote mail server after RCPT TO:<lqkwrzreonkhhtql@terraoil.ru>: host mail-s56.1gb.ru [81.177.159.3]: 553 We do not relay without RFC2554 authentication.' },
      ]},
);

test_search("Search for email 'lqkwrzreonkhhtql\@terraoil.ru' with bounce" => { include_bounce => 0 } =>  join("\n",
    '2012-02-13 14:59:56 1RwtdJ-0000Ac-Ch == lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set',
    '2012-02-13 15:02:02 1RwtdJ-0000Ac-Ch ** lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp: SMTP error from remote mail server after RCPT TO:<lqkwrzreonkhhtql@terraoil.ru>: host mail-s56.1gb.ru [81.177.159.3]: 553 We do not relay without RFC2554 authentication.',
    '2012-02-13 15:02:02 1RwtfW-000LYI-8j <= <> R=1RwtdJ-0000Ac-Ch U=mailnull P=local S=3509',
  ),
  'lqkwrzreonkhhtql@terraoil.ru' => {
      render=> 'JSON',
      data=>[
        { int_id => "1RwtdJ-0000Ac-Ch", o_id => 1, t => "log", created => "2012-02-13 14:59:56", str => '1RwtdJ-0000Ac-Ch == lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set' },
        { int_id => "1RwtdJ-0000Ac-Ch", o_id => 2, t => "log", created => "2012-02-13 15:02:02", str => '1RwtdJ-0000Ac-Ch ** lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp: SMTP error from remote mail server after RCPT TO:<lqkwrzreonkhhtql@terraoil.ru>: host mail-s56.1gb.ru [81.177.159.3]: 553 We do not relay without RFC2554 authentication.' },
      ]},
);

test_search("Search for email 'lqkwrzreonkhhtql\@terraoil.ru' with bounce" => { include_bounce => 1 } =>  join("\n",
    '2012-02-13 14:59:56 1RwtdJ-0000Ac-Ch == lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set',
    '2012-02-13 15:02:02 1RwtdJ-0000Ac-Ch ** lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp: SMTP error from remote mail server after RCPT TO:<lqkwrzreonkhhtql@terraoil.ru>: host mail-s56.1gb.ru [81.177.159.3]: 553 We do not relay without RFC2554 authentication.',
    '2012-02-13 15:02:02 1RwtfW-000LYI-8j <= <> R=1RwtdJ-0000Ac-Ch U=mailnull P=local S=3509',
  ),
  'lqkwrzreonkhhtql@terraoil.ru' => {
      render=> 'JSON',
      data=>[
        { int_id => "1RwtdJ-0000Ac-Ch", o_id => 1, t => "log", created => "2012-02-13 14:59:56", str => '1RwtdJ-0000Ac-Ch == lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set' },
        { int_id => "1RwtdJ-0000Ac-Ch", o_id => 2, t => "log", created => "2012-02-13 15:02:02", str => '1RwtdJ-0000Ac-Ch ** lqkwrzreonkhhtql@terraoil.ru R=dnslookup T=remote_smtp: SMTP error from remote mail server after RCPT TO:<lqkwrzreonkhhtql@terraoil.ru>: host mail-s56.1gb.ru [81.177.159.3]: 553 We do not relay without RFC2554 authentication.' },
        { int_id => "1RwtfW-000LYI-8j", o_id => 3, t => "message_bounce", created => "2012-02-13 15:02:02", str => '1RwtfW-000LYI-8j <= <> R=1RwtdJ-0000Ac-Ch U=mailnull P=local S=3509' },
      ]},
);


#is(1, 1);
done_testing;