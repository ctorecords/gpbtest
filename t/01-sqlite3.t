use strict;
use warnings;
use Test::More;
use lib::abs '../lib';
use GPBExim;
use uni::perl ':dumper';
use Try::Tiny;

my $dbh; # = GPBExim::db_connect('SQLite3::Memory');
#GPBExim::setup_schema($dbh);

sub  open_log { if (open(my $fh, "<$_[0]")) { return $fh } else { die "Не могу открыть файл '$_[0]' $!" } }
sub close_log { close $_[0] }

our $MAX_CHUNKS = 1024;
our $CHUNK_SIZE = 1024*1024;

# читаем $CHUNK_SIZE полных строк лога, оканчивающихся \n в файле,
# постепенно передвигая в нём каретку от итерации к итерации
sub get_next_chunk_from_log {
    my ($fh) = @_;
    my $buf;
    my $pos_before = tell($fh);

    # Читаем чанк
    my $read_bytes = read($fh, $buf, $CHUNK_SIZE);
    if (!defined $read_bytes) {
        warn "Ошибка чтения: $!";
        return undef;
    }
    return undef unless $read_bytes;  # EOF, ничего не прочитали

    my $last_newline_pos = rindex($buf, "\n");

    # если есть \n — стандартный случай
    if ($last_newline_pos >= 0) {
        my $rollback_bytes = $read_bytes - $last_newline_pos - 1;
        seek($fh, -$rollback_bytes, 1) or warn "Seek назад не удался: $!";
        return substr($buf, 0, $last_newline_pos + 1);
    }

    # нет \n, но достигнут конец файла — вернуть остаток
    if (eof($fh)) {
        return $buf;
    }

    # нет \n и не eof — строка слишком длинная, отбросим
    seek($fh, $pos_before, 0) or warn "Seek назад не удался: $!";
    warn "Длинная строка без новой строки — $CHUNK_SIZE байт проигнорированы";
    return undef;
}

sub txn {
    my $dbh = shift;
    my $cb  = shift;
    $dbh->{RaiseError} = 1;

    try {
        $dbh->do('BEGIN TRANSACTION');
        $cb->($dbh);
        $dbh->do('COMMIT');
    } catch {
        warn "Transaction aborted because $_";
        eval { $dbh->do('ROLLBACK') };
    };
}

sub parse_line {
    my $line = shift;

    my ($datetime, $int_id, $flag, $email, $other) =
            $line =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (\S+) (<=|=>|\*\*|==|->)? ?<?([^>\s]+@[^>\:\s]+)?>?(.*?)$/;
    $other =~ s/^\:?\s+//g;
    return if !$datetime;

    return {
        datetime => $datetime,
        int_id   => $int_id,
        flag     => $flag,
        email    => $email,
        other    => $other,
    };
}

our %emails=();
sub parse_chunk {
    my $dbh = shift;
    my $chunk = shift;
    my %args = @_;

    my %_sth = (
        insert_log            => qq{ insert into log (created, int_id, str, address_id) values(?, ?, ?, ?) },
        insert_message        => qq{ insert into message (id, created, int_id, str, address_id) values(?, ?, ?, ?, ?) },
        insert_message_bounce => qq{ insert into message_bounce (created, int_id, address_id, reason_id, str) values(?, ?, ?, ?, ?) },
        insert_address        => qq{ insert into message_address (created, address, status) values(?, ?, ?) },

        get_message_by_id     => qq{ select id, created, int_id, str from message where id=? },
        get_address_by_email  => qq{ select id, created, address, status from message_address where address=? },

        get_message_and_log_by_int_id => qq{
            select
                created as created,
                address_id as address_id,
                str as str
            from log
            where  int_id=?

            union

            select
                created as created,
                address_id as address_id,
                str as str
            from message
            where  int_id=?

            order by created desc, str desc
        },
        get_log_by_all => qq{
            select
                log.created,
                log.int_id,
                log.str,
                log.address_id
            from log
            where  log.int_id=? and created=? and str=? and address_id=?
        },

    );
    my $sth={ map { $_ => $dbh->prepare_cached($_sth{$_}) } keys %_sth };



    for my $line (split /\n/, $chunk) {
        if (my $parsed = parse_line($line)) {
            my ($datetime, $int_id, $flag, $email, $other) = @$parsed{qw/datetime int_id flag email other/};
            my $stripped_line = $line; $stripped_line =~ s/^$datetime\s+//g;

            # проверим, что email есть в таблице messaage_address и в кешируем хеше %emails
            my ($address_id);
            if ($email and !$emails{$email}) {
                $sth->{get_address_by_email}->execute($email)  or die $sth->{get_address_by_email}->errstr;
                my $address = $sth->{get_address_by_email}->fetchrow_hashref();
                if (!$address) {
                    $sth->{insert_address}->execute($datetime, $email, 'unknown')  or die $sth->{insert_address}->errstr;
                    $emails{$email}= $address_id = $dbh->last_insert_id;
                }
                else {
                    $emails{$email}= $address_id = $address->{id};
                }
            }
            else {
                $address_id=$emails{$email};
            }
            if ($flag eq '<=') {
                my $id; ($id) = $other =~ /id=([^\s]+)/;

                # запись в messages, если это не bounce
                if ($id) {
                    # обеспечим идемпотентность (при повторном "проигрывании" лога записи в БД не дублируем)
                    # здесь для демонстрации показываем обеспечение на уровне логики в perl.
                    # В других местах покажу решение на уровне sql
                    $sth->{get_message_by_id}->execute($id)
                        or die $sth->{get_message_by_id}->errstr;
                    my @message = $sth->{get_message_by_id}->fetchrow_array;
                    if (!@message) {
                        $sth->{insert_message}->execute($id, $datetime, $int_id, $stripped_line, $address_id)
                            or die $sth->{insert_message}->errstr;
                    };
                }
                else {
                    # выделим ссылку int_id из переменной R= и попытаемся найти в БД строки с int_id.
                    my $rel_int_id; ($rel_int_id) = $other =~ /R=([^\s]+)/;

                    $sth->{get_message_and_log_by_int_id}->execute($rel_int_id, $rel_int_id)
                        or die $sth->{get_message_and_log_by_int_id}->errstr;
                    my $rows = $sth->{get_message_and_log_by_int_id}->fetchall_arrayref({});

                    my $email_found_for_bounce;
                    EMAILSEARCH: for my $row (@$rows) {
                        if ($row->{address_id}) {
                            $email_found_for_bounce = 1;
                            $sth->{insert_message_bounce}->execute($datetime, $int_id, $row->{address_id}, undef, $stripped_line)
                                or die $sth->{insert_message_bounce}->errstr;
                            last EMAILSEARCH;
                        }
                    }
                    # если email для bounce не определён, то кидаем его бед address_id на случай,
                    # когда в будущем в логе докинут данные по нему
                    if (!$email_found_for_bounce) {
                        $sth->{insert_message_bounce}->execute($datetime, $int_id, undef, undef, $stripped_line)
                            or die $sth->{insert_message_bounce}->errstr;
                    }
                }
            }
            # все остальные записи кидаем в лог
            else {
                $sth->{get_log_by_all}->execute($int_id, $datetime, $stripped_line, $address_id)
                    or die $sth->{get_log_by_all}->errstr;
                my $log = $sth->{get_log_by_all}->fetchall_arrayref({});
                if (!@$log) {
                    $sth->{insert_log}->execute($datetime, $int_id, $stripped_line, $address_id)
                        or die $sth->{insert_log}->errstr;
                }
            }
        }
    }

    # зафинишим все стейтменты
    $_->finish() for (values %$sth);

}

#$dbh = GPBExim::db_connect('SQLite3::File'); GPBExim::setup_schema($dbh);
#
#if (my $LOG_FH = open_log(lib::abs::path('../temp/maillog'))) {
#    my $chunk_counter = 0;
#
#    # читаем лог чанками
#    CHUNKS: while (!eof($LOG_FH) and ++$chunk_counter<$MAX_CHUNKS ) {
#        # ... и внутри чанка транзакциями обновляем БД
#        my $chunk = get_next_chunk_from_log($LOG_FH) or last CHUNKS;
#        txn($dbh => sub {
#            my $_dbh = shift;
#            parse_chunk($_dbh => $chunk);
#        });
#    };
#
#    close_log($LOG_FH);
#}
#$dbh->disconnect(); %emails=();

#parse_chunk($dbh, q{
#2012-02-13 14:39:22 1RookS-000Pg8-VO == udbbwscdnbegrmloghuf@london.com R=dnslookup T=remote_smtp defer (-44): SMTP error from remote mail server after RCPT TO:<udbbwscdnbegrmloghuf@london.com>: host mx0.gmx.com [74.208.5.90]: 450 4.3.2 Too many mails (mail bomb), try again in 1 hour(s) 25 minute(s) and see ( http://portal.gmx.net/serverrules ) {mx-us011}
#2012-02-13 14:39:22 1RookS-000Pg8-VO ** fwxvparobkymnbyemevz@london.com: retry timeout exceeded
#2012-02-13 14:39:22 1RwtJa-000AFJ-3B <= <> R=1RookS-000Pg8-VO U=mailnull P=local S=3958
#2012-02-13 14:39:22 1RookS-000Pg8-VO Completed
#});

#done_testing;
#exit;


# тесты парсера с регэкспом строк exim logs
is_deeply(parse_line(
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

is_deeply(parse_line(
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

is_deeply(parse_line(
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

is_deeply(parse_line(
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

is_deeply(parse_line(
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



%emails=();
# тесты парсера чанков, загружающего данные в БД

#$dbh->disconnect();



###########################################
# Простая группа строк с bounce
%emails=(); $dbh = GPBExim::db_connect('SQLite3::Memory'); GPBExim::setup_schema($dbh);
parse_chunk($dbh, join(' ',
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
        message         => $dbh->selectall_arrayref("select * from message", { Slice => {} }),
        message_address => $dbh->selectall_arrayref("select * from message_address order by id", { Slice => {} }),
        message_bounce  => $dbh->selectall_arrayref("select * from message_bounce", { Slice => {} }),
        bounce_reasons  => $dbh->selectall_arrayref("select * from bounce_reasons", { Slice => {} }),
        log             => $dbh->selectall_arrayref("select * from log order by int_id, created, str", { Slice => {} }),
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
$dbh->disconnect();

###########################################
# Простая группа строк с успешной отправкой
%emails=(); $dbh = GPBExim::db_connect('SQLite3::Memory'); GPBExim::setup_schema($dbh);
parse_chunk($dbh, join("\n",
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 <= ysxeuila@rushost.ru H=rtmail.rushost.ru [109.70.26.4] P=esmtp S=3211 id=rt-3.8.8-21135-1329129970-559.3914282-6-0@rushost.ru},
        q{2012-02-13 14:46:10 1RwtQA-000Mti-P5 == ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp defer (-1): domain matches queue_smtp_domains, or -odqs set},
        q{2012-02-13 14:46:14 1RwtQA-000Mti-P5 => ijcxzetfsijoedyg@hsrail.ru R=dnslookup T=remote_smtp H=mx.hsrail.ru [213.33.220.238] C="250 2.6.0  <tiraramrjynnyexlzbjmsiobtgwwsitbvgnatrbtid@rushost.ru> Queued mail for delivery"},
        q{2012-02-13 14:46:14 1RwtQA-000Mti-P5 Completed},
));
is_deeply(
    {
        message         => $dbh->selectall_arrayref("select * from message", { Slice => {} }),
        message_address => $dbh->selectall_arrayref("select * from message_address order by id", { Slice => {} }),
        message_bounce  => $dbh->selectall_arrayref("select * from message_bounce", { Slice => {} }),
        bounce_reasons  => $dbh->selectall_arrayref("select * from bounce_reasons", { Slice => {} }),
        log             => $dbh->selectall_arrayref("select * from log order by int_id, created, str", { Slice => {} }),
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
$dbh->disconnect();
done_testing;
