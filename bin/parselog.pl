#!/usr/bin/env perl
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Parser;
use GPBExim::Config;
use Getopt::Long;
use Cwd qw(abs_path);

# Опция --no-setup нужна для случаев, когда
# парсим последовательно несколько лог-файлов для накопления информации о них
my $no_setup;
GetOptions(
    'no-setup' => \$no_setup,
) or die "Неверные параметры запуска. Использование: $0 [--no-setup] <logfile_path>\n";

my $logfile = shift @ARGV or die "Не передан путь к лог-файлу. Использование: $0 [--no-setup] <logfile_path>\n";

$logfile = abs_path($logfile) or die "Не удалось определить абсолютный путь к '$logfile'\n";
-f $logfile or die "Файл '$logfile' не существует или не является обычным файлом\n";

my $cfg = GPBExim::Config->get();

my $model;
my $parser;

$model = GPBExim::get_model($cfg->{db}{model_type},
        rm_xapian_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        rm_xapian_db_on_init    => $cfg->{xapian}{clear_db_on_init},
        clear_db_on_init        => $cfg->{db}{clear_db_on_init},
        clear_db_on_destroy     => $cfg->{db}{clear_db_on_destroy},
);
$model->setup_schema() unless $no_setup;
$parser = GPBExim::Parser->new();


if (my $LOG_FH = $parser->open_log($logfile)) {
    my $chunk_counter = 0;

    # читаем лог чанками
    CHUNKS: while (!eof($LOG_FH) and ++$chunk_counter<$parser->{max_chunks} ) {
        # ... и внутри чанка транзакциями обновляем БД
        my $chunk = $parser->get_next_chunk_from_log($LOG_FH)
            or last CHUNKS;
        $model->txn(sub {
            my %args = @_;
            $parser->parse_chunk($model => $chunk, @_);
        });
    };

    $parser->close_log($LOG_FH);
}
