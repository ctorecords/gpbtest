use Test::More;
use lib::abs 'lib';
use uni::perl ':dumper';
use GPBExim::TestHelper qw(test_parse_line test_parse_chunk);


test_parse_line ( 'Проверка парсера регэкспом строки с ошибкой Too many mails (mail bomb)' =>
    '2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}',
    {
        datetime => '2012-02-13 14:39:22',
        int_id   => '1RookS-000Pg8-VO',
        flag     => '==',
        email    => 'udbbwscdnbegrmloghuf@london.com',
        other    => 'R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}',
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

done_testing;