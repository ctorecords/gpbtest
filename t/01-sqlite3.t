use Test::More;
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Controller;

my $model;
my $controller;

# тесты парсера с регэкспом строк exim logs
$controller = GPBExim::Controller->new();

is_deeply($controller->parse_line(
    join(' ',
        q{2012-02-13 14:39:22},
        q{1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com},
        q{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>:},
        q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
        q{( http://portal.gmx.net/serverrules ) {mx-us011}})
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
    }, 'Проверка парсера регэкспом строки с ошибкой Too many mails (mail bomb)',
);

is_deeply($controller->parse_line(
    join(' ',
        q{2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz@london.com: retry timeout exceeded})
    ),
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RookS-000Pg8-VO',
        flag     => '**',
        email    => 'fwxvparobkymnbyemevz@london.com',
        other    => q{retry timeout exceeded},
    }, 'Проверка парсера регэкспом строки retry timeout exceeded',
);

is_deeply($controller->parse_line(
    join(' ',
        q{2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958})
    ),
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RwtJa-000AFJ-3B',
        flag     => '<=',
        email    => undef,
        other    => q{R=1RookS-000Pg8-VO U=mailnull P=local S=3958},
    }, 'Проверка парсера регэкспом строки с bounce',
);

is_deeply($controller->parse_line(
    join(' ',
        q{2012-02-13 14:39:22 1RookS-000Pg8-VO Completed}
    )),
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RookS-000Pg8-VO',
        flag     => undef,
        email    => undef,
        other    => q{Completed},
    }, 'Проверка парсера регэкспом строки Completed');

is_deeply($controller->parse_line(
    join(' ',
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set}
    )),
    {
        datetime => '2012-02-13 14:46:10',
        int_id   => '1RwtQA-000Mti-P5',
        flag     => '==',
        email    => 'ijcxzetfsijoedyg@hsrail.ru',
        other    => q{R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
    }, 'Проверка парсера регэкспом строки domain matches queue_smtp_domains');
undef $controller;


# тесты парсера чанков, загружающего данные в БД

#$dbh->disconnect();



###########################################
# Простая группа строк с bounce

undef $model, $controller; $model = GPBExim::get_model('SQLite3::Memory'); $model->setup_schema();
$controller = GPBExim::Controller->new();

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
is_deeply(
    {
        message         => $model->{dbh}->selectall_arrayref("select * from message", { Slice => {} }),
        message_address => $model->{dbh}->selectall_arrayref("select * from message_address order by id", { Slice => {} }),
        message_bounce  => $model->{dbh}->selectall_arrayref("select * from message_bounce", { Slice => {} }),
        bounce_reasons  => $model->{dbh}->selectall_arrayref("select * from bounce_reasons", { Slice => {} }),
        log             => $model->{dbh}->selectall_arrayref("select * from log order by int_id, created, str", { Slice => {} }),
    },
    {
        message         => [],
        message_address => [
            { created => "2012-02-13 14:39:22", status => "unknown", address => "udbbwscdnbegrmloghuf\@london.com", id => 1 },
            { created => "2012-02-13 14:39:22", status => "unknown", address => "fwxvparobkymnbyemevz\@london.com", id => 2 },
        ],
        message_bounce  => [
            { created => "2012-02-13 14:39:22", reason_id => undef, int_id => "1RwtJa-000AFJ-3B", address_id => 1,
                str => "1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958" }
        ],
        bounce_reasons  => [],
        log => [
            { str => "1RookS-000Pg8-VO ** fwxvparobkymnbyemevz\@london.com: retry timeout exceeded", created => "2012-02-13 14:39:22", int_id => "1RookS-000Pg8-VO", address_id => 2 },
            { created => "2012-02-13 14:39:22", int_id => "1RookS-000Pg8-VO", address_id => 1,
                str => join(' ',
                    q{1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com},
                    q{R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>:},
                    q{host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see},
                    q{( http://portal.gmx.net/serverrules ) {mx-us011}},

                ),
            },
            { str => q{1RookS-000Pg8-VO Completed}, created => "2012-02-13 14:39:22", int_id => "1RookS-000Pg8-VO", address_id => undef },

        ]
    },
    '4 lines'
);
undef $model, $controller;

###########################################
# Простая группа строк с успешной отправкой
undef $model, $controller; $model = GPBExim::get_model('SQLite3::Memory'); $model->setup_schema();
$controller = GPBExim::Controller->new();

$controller->parse_chunk($model => join("\n",
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 <= ysxeuila@rushost.ru H=rtmail.rushost.ru [109.70.26.4] P=esmtp S=3211 id=rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru},
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
        q{2012-02-13 14:46:14 1RwtQA-000Mti-P5 => ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp H=mx.hsrail.ru [213.33.220.238] C="250 2.6.0  <tiraramrjynnyexlzbjmsiobtgwwsitbvgnatrbtid@rushost.ru> Queued mail for delivery"},
        q{2012-02-13 14:46:14 1RwtQA-000Mti-P5 Completed},
));
is_deeply(
    {
        message         => $model->{dbh}->selectall_arrayref("select * from message", { Slice => {} }),
        message_address => $model->{dbh}->selectall_arrayref("select * from message_address order by id", { Slice => {} }),
        message_bounce  => $model->{dbh}->selectall_arrayref("select * from message_bounce", { Slice => {} }),
        bounce_reasons  => $model->{dbh}->selectall_arrayref("select * from bounce_reasons", { Slice => {} }),
        log             => $model->{dbh}->selectall_arrayref("select * from log order by int_id, created, str", { Slice => {} }),
    },
    {
        message         => [
            { str => q{1RwtQA-000Mti-P5 <= ysxeuila@rushost.ru H=rtmail.rushost.ru [109.70.26.4] P=esmtp S=3211 id=rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru},
                created => "2012-02-13 14:46:10", int_id => "1RwtQA-000Mti-P5", address_id => 1, status => undef, id=>'rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru' },
        ],
        message_address => [
            { created => "2012-02-13 14:46:10", status => "unknown", address => "ysxeuila\@rushost.ru", id => 1 },
            { created => "2012-02-13 14:46:10", status => "unknown", address => "ijcxzetfsijoedyg\@hsrail.ru", id => 2 },
        ],
        message_bounce  => [],
        bounce_reasons  => [],
        log => [
            { str => q{1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
                created => "2012-02-13 14:46:10", int_id => "1RwtQA-000Mti-P5", address_id => 2 },
            { created => "2012-02-13 14:46:14", int_id => "1RwtQA-000Mti-P5", address_id => 2,
                str => join(' ',
                    q{1RwtQA-000Mti-P5 => ijcxzetfsijoedyg@hsrail.ru},
                    q{R=dnslookup T=remote_smtp H=mx.hsrail.ru [213.33.220.238] C="250 2.6.0  <tiraramrjynnyexlzbjmsiobtgwwsitbvgnatrbtid@rushost.ru>},
                    q{Queued mail for delivery"},
                ),
            },
            { str => q{1RwtQA-000Mti-P5 Completed}, created => "2012-02-13 14:46:14", int_id => "1RwtQA-000Mti-P5", address_id => undef },

        ]
    },
    'Простая группа строк с успешной отправкой'
);
undef $model;
done_testing;
