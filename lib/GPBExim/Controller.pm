package GPBExim::Controller;
use uni::perl ':dumper';
use lib::abs;


sub new {
    my $pkg = shift;
    my $self = bless {
        max_chunks => 1024*1024,
        chunk_size => 1024*1024*10,

        @_
    }, $pkg;

    return $self;
}

sub parse_line {
    my $self = shift;
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

sub parse_logfile {
    my $self      = shift;
    my $file_path = shift;
    my $model     = shift;

    my %args = ( @_ );

    if (my $LOG_FH = $self->open_log($file_path)) {
        my $chunk_counter = 0;

        # читаем лог чанками
        CHUNKS: while (!eof($LOG_FH) and ++$chunk_counter<$self->{max_chunks} ) {
            # ... и внутри чанка транзакциями обновляем БД
            my $chunk = $self->get_next_chunk_from_log($LOG_FH)
                or last CHUNKS;
            $model->txn(sub {
                my %args = @_;
                $self->parse_chunk($model => $chunk, @_);
            });
        };

        $self->close_log($LOG_FH);
    }
}

sub parse_chunk {
    my $self = shift;
    my $model = shift;
    my $chunk = shift;
    my %args = @_;

    my %_sth = (
        insert_log            => qq{ insert into log (created, int_id, str, address_id, o_id) values(?, ?, ?, ?, ?) },
        insert_message        => qq{ insert into message (id, created, int_id, str, address_id, o_id) values(?, ?, ?, ?, ?, ?) },
        insert_message_bounce => qq{ insert into message_bounce (created, int_id, address_id, str, o_id) values(?, ?, ?, ?, ?) },
        insert_address        => qq{ insert into message_address (created, address) values(?, ?) },

        get_message_by_id     => qq{ select id, created, int_id, str from message where id=? },
        get_address_by_email  => qq{ select id, created, address from message_address where address=? },

        get_message_and_log_by_int_id => qq{
            select
                created as created,
                address_id as address_id,
                str as str,
                o_id
            from log
            where  int_id=?

            union

            select
                created as created,
                address_id as address_id,
                str as str,
                o_id
            from message
            where  int_id=?

            order by o_id desc
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
    $self->{sth}={ map { $_ => $model->{dbh}->prepare_cached($_sth{$_}) } keys %_sth };

    my @lines = split /\n/, $chunk;
    my $lines_count = @lines;
    my $line_counter=0;
    for my $line (@lines) {
        ++$line_counter;
        if (my $parsed = $self->parse_line($line)) {
            my ($datetime, $int_id, $flag, $email, $other) = @$parsed{qw/datetime int_id flag email other/};
            my $stripped_line = $line; $stripped_line =~ s/^$datetime\s+//g;

            # проверим, что email есть в таблице messaage_address и в кешируем хеше $self->{emails}
            my ($address_id);
            if ($email and !$self->{emails}{$email}) {
                $self->{sth}{get_address_by_email}->execute($email)
                    or die $self->{sth}{get_address_by_email}->errstr;
                my $address = $self->{sth}{get_address_by_email}->fetchrow_hashref();
                if (!$address) {
                    $self->{sth}{insert_address}->execute($datetime, $email)
                        or die $self->{sth}{insert_address}->errstr;
                    $self->{emails}{$email}= $address_id = $model->{dbh}->last_insert_id;
                    $model->index_address_at_xapian($email => $address_id);
                }
                else {
                    $self->{emails}{$email}= $address_id = $address->{id};
                }
            }
            else {
                $address_id=$self->{emails}{$email};
            }
            if ($flag eq '<=') {
                my $id; ($id) = $other =~ /id=([^\s]+)/;

                # запись в messages, если это не bounce
                if ($id) {
                    # обеспечим идемпотентность (при повторном "проигрывании" лога записи в БД не дублируем)
                    # здесь для демонстрации показываем обеспечение на уровне логики в perl.
                    # В других местах покажу решение на уровне sql
                    $self->{sth}{get_message_by_id}->execute($id)
                        or die $self->{sth}{get_message_by_id}->errstr;
                    my @message = $self->{sth}{get_message_by_id}->fetchrow_array;
                    if (!@message) {
                        $self->{sth}{insert_message}->execute($id, $datetime, $int_id, $stripped_line, $address_id, $model->get_next_o_id)
                            or die $self->{sth}{insert_message}->errstr;
                    };
                }
                else {
                    # выделим ссылку int_id из переменной R= и попытаемся найти в БД строки с int_id.
                    my $rel_int_id; ($rel_int_id) = $other =~ /R=([^\s]+)/;

                    $self->{sth}{get_message_and_log_by_int_id}->execute($rel_int_id, $rel_int_id)
                        or die $self->{sth}{get_message_and_log_by_int_id}->errstr;
                    my $rows = $self->{sth}{get_message_and_log_by_int_id}->fetchall_arrayref({});

                    my $email_found_for_bounce;
                    EMAILSEARCH: for my $row (@$rows) {
                        if ($row->{address_id}) {
                            $email_found_for_bounce = 1;
                            $self->{sth}{insert_message_bounce}->execute($datetime, $int_id, $row->{address_id}, $stripped_line, $model->get_next_o_id)
                                or die $self->{sth}{insert_message_bounce}->errstr;
                            last EMAILSEARCH;
                        }
                    }
                    # если email для bounce не определён, то кидаем его бед address_id на случай,
                    # когда в будущем в логе докинут данные по нему
                    if (!$email_found_for_bounce) {
                        $self->{sth}{insert_message_bounce}->execute($datetime, $int_id, undef, $stripped_line, $model->get_next_o_id)
                            or die $self->{sth}{insert_message_bounce}->errstr;
                    }
                }
            }
            # все остальные записи кидаем в лог
            else {
                $self->{sth}{get_log_by_all}->execute($int_id, $datetime, $stripped_line, $address_id)
                    or die $self->{sth}{get_log_by_all}->errstr;
                my $log = $self->{sth}{get_log_by_all}->fetchall_arrayref({});
                if (!@$log) {
                    $self->{sth}{insert_log}->execute($datetime, $int_id, $stripped_line, $address_id, $model->get_next_o_id)
                        or die $self->{sth}{insert_log}->errstr;
                }
            }
        }
    }
}

# открытие и закрытие файлов лога для почанковой записи
sub  open_log { my $self = shift; if (open(my $fh, "<$_[0]")) { binmode($fh, ":raw"); return $fh } else { die "Не могу открыть файл '$_[0]' $!" } }
sub close_log { my $self = shift; close $_[0] }

# читаем $self->{chunk_size} полных строк лога, оканчивающихся \n в файле,
# постепенно передвигая в нём каретку от итерации к итерации
sub get_next_chunk_from_log {
    my $self = shift;

    my ($fh) = @_;
    my $buf;
    my $pos_before = tell($fh);

    # Читаем чанк
    my $read_bytes = read($fh, $buf, $self->{chunk_size});
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
    warn "Длинная строка без новой строки — ".$self->{chunk_size}." байт проигнорированы";
    return undef;
}


sub DESTROY {
    my $self = shift;

    # зафинишим все стейтменты
    $_->finish() for (values %{$self->{sth}});
}

1;