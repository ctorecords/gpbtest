use Test::More;
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim::Test qw(test_parse_line test_parse_chunk);


test_parse_line ( 'Проверка парсера регэкспом строки с ошибкой Too many mails (mail bomb)' =>
    join(' ',
        q{2012-02-13 14:39:22},
        q{1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com},
        q{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>:},
        q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
        q{( http://portal.gmx.net/serverrules ) {mx-us011}}
    ),
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RookS-000Pg8-VO',
        flag     => '==',
        email    => 'udbbwscdnbegrmloghuf@london.com',
        other    => join(' ',
            q{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>:},
            q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
            q{( http://portal.gmx.net/serverrules ) {mx-us011}}),
    }
);

test_parse_line ( 'Проверка парсера регэкспом строки retry timeout exceeded' =>
    '2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz@london.com: retry timeout exceeded',
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RookS-000Pg8-VO',
        flag     => '**',
        email    => 'fwxvparobkymnbyemevz@london.com',
        other    => q{retry timeout exceeded},
    }
);

test_parse_line ( 'Проверка парсера регэкспом строки с bounce' =>
    '2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958',
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RwtJa-000AFJ-3B',
        flag     => '<=',
        email    => undef,
        other    => q{R=1RookS-000Pg8-VO U=mailnull P=local S=3958},
    }
);

test_parse_line ( 'Проверка парсера регэкспом строки Completed' =>
    '2012-02-13 14:39:22 1RookS-000Pg8-VO Completed',
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RookS-000Pg8-VO',
        flag     => undef,
        email    => undef,
        other    => q{Completed},
    }
);

test_parse_line ( 'Проверка парсера регэкспом строки domain matches queue_smtp_domains' =>
    '2012-02-13 14:46:10 1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set',
    {
        datetime => '2012-02-13 14:46:10',
        int_id   => '1RwtQA-000Mti-P5',
        flag     => '==',
        email    => 'ijcxzetfsijoedyg@hsrail.ru',
        other    => q{R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
    }
);

test_parse_chunk( '4 lines' => join(' ',
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
        q{2012-02-13 14:39:22 1RookS-000Pg8-VO Completed},

    {
        message_address => [
            { created => "2012-02-13 14:39:22", status => "unknown", address => "udbbwscdnbegrmloghuf\@london.com", id => 1 },
            { created => "2012-02-13 14:39:22", status => "unknown", address => "fwxvparobkymnbyemevz\@london.com", id => 2 },
        ],
        message_bounce  => [
            { created => "2012-02-13 14:39:22", reason_id => undef, int_id => "1RwtJa-000AFJ-3B", address_id => 2,
                str => "1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958", o_id=> "3" }
        ],
        log => [
            { created => "2012-02-13 14:39:22", int_id => "1RookS-000Pg8-VO", address_id => 1, o_id=> "1",
                str => join(' ',
                    q{1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com},
                    q{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>:},
                    q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
                    q{( http://portal.gmx.net/serverrules ) {mx-us011}},

                ),
            },
            { str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded", created => "2012-02-13 14:39:22", int_id => "1RookS-000Pg8-VO", address_id => 2, o_id=> "2" },
            { str => q{1RookS-000Pg8-VO Completed}, created => "2012-02-13 14:39:22", int_id => "1RookS-000Pg8-VO", address_id => undef, o_id=> "4" },

        ]
    },
    rm_xapian_db_on_destroy => 1, rm_xapian_db_on_init => 1,
);



test_parse_chunk( 'Простая группа строк с успешной отправкой' => join("\n",
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 <= ysxeuila@rushost.ru H=rtmail.rushost.ru [109.70.26.4] P=esmtp S=3211 id=rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru},
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
        q{2012-02-13 14:46:14 1RwtQA-000Mti-P5 => ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp H=mx.hsrail.ru [213.33.220.238] C="250 2.6.0  <tiraramrjynnyexlzbjmsiobtgwwsitbvgnatrbtid@rushost.ru> Queued mail for delivery"},
        q{2012-02-13 14:46:14 1RwtQA-000Mti-P5 Completed} ),

    {
        message         => [
            { o_id => "1", str => q{1RwtQA-000Mti-P5 <= ysxeuila@rushost.ru H=rtmail.rushost.ru [109.70.26.4] P=esmtp S=3211 id=rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru},
                created => "2012-02-13 14:46:10", int_id => "1RwtQA-000Mti-P5", address_id => 1, status => undef, id=>'rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru' },
        ],
        message_address => [
            { created => "2012-02-13 14:46:10", status => "unknown", address => "ysxeuila\@rushost.ru", id => 1 },
            { created => "2012-02-13 14:46:10", status => "unknown", address => "ijcxzetfsijoedyg\@hsrail.ru", id => 2 },
        ],
        message_bounce  => [],
        bounce_reasons  => [],
        log => [
            { o_id => "2", str => q{1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
                created => "2012-02-13 14:46:10", int_id => "1RwtQA-000Mti-P5", address_id => 2 },
            { o_id => "3", created => "2012-02-13 14:46:14", int_id => "1RwtQA-000Mti-P5", address_id => 2,
                str => join(' ',
                    q{1RwtQA-000Mti-P5 => ijcxzetfsijoedyg@hsrail.ru},
                    q{R=dnslookup T=remote_smtp H=mx.hsrail.ru [213.33.220.238] C="250 2.6.0  <tiraramrjynnyexlzbjmsiobtgwwsitbvgnatrbtid@rushost.ru>},
                    q{Queued mail for delivery"},
                ),
            },
            { o_id => "4", str => q{1RwtQA-000Mti-P5 Completed}, created => "2012-02-13 14:46:14", int_id => "1RwtQA-000Mti-P5", address_id => undef },

        ]
    },
    rm_xapian_db_on_destroy => 1, rm_xapian_db_on_init => 1,
);

done_testing;
