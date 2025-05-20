use strict;
use warnings;
use Test::More;
use lib::abs '../lib';
use GPBExim;
use bytes;
use uni::perl ':dumper';

my $dbh = GPBExim::db_connect('SQLite3::File');
GPBExim::setup_schema($dbh);

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

if (my $LOG_FH = open_log(lib::abs::path('../temp/maillog'))) {
    my $chunk_counter = 0;
    my $line_counter = 0;


    # читаем чанками
    CHUNKS: while (!eof($LOG_FH) and ++$chunk_counter<$MAX_CHUNKS ) {
        my $chunk = get_next_chunk_from_log($LOG_FH) or last CHUNKS;
        for my $line (split /\n/, $chunk) {
            $line_counter++;
            if (my ($date, $time, $int_id, $flag, $email, $other) = 
                $line =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) (\S+) (<=|=>|\*\*|==|->)? ?<?([^>\s]+@[^>\s]+)?>?(.*)$/) {
                my $stripped_line = $line; $stripped_line =~ s/$date $time\s+//g;
                if ($flag eq '<=') {
                    my $id; ($id) = $other =~ /id=([^\s]+)/;
                    if (!$id) {
                        #print $line, $/;
                    }
                    else {
                        #print $stripped_line, " / id=$id",$/;
                    }
                    #print dumper({date=>$date, time=>$time, int_id=>$int_id, flag=>$flag, email=>$email, other=>$other, stripped_line=>$stripped_line, id=> $id // ''});
                }
                elsif ($flag eq '=>') {
                    #print $int_id, ': ', $email, $/;
                }
            } else {
                #print "Проблемная строка №$line_counter: ", $line;
            }
        }
    }

    close_log($LOG_FH);
}


is (1,1, "Default test");
done_testing;
