use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Controller;
use GPBExim::Config;
use Getopt::Long;
use Cwd qw(abs_path);

my $cfg = GPBExim::Config->get();

my $model;
my $controller;

my $logfile;
my @args = @ARGV;

$logfile = shift @args or die "Не передан путь к лог-файлу. Использование: $0 <logfile_path>\n";

$logfile = abs_path($logfile) or die "Не удалось определить абсолютный путь к '$logfile'\n";
-f $logfile or die "Файл '$logfile' не существует или не является обычным файлом\n";


$model = GPBExim::get_model($cfg->{db}{model_type},
        rm_xapian_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        rm_xapian_db_on_init    => $cfg->{xapian}{clear_db_on_init},
        clear_db_on_init        => $cfg->{db}{clear_db_on_init},
        clear_db_on_destroy     => $cfg->{db}{clear_db_on_destroy},
)
    ->setup_schema();
$controller = GPBExim::Controller->new();


if (my $LOG_FH = $controller->open_log($logfile)) {
    my $chunk_counter = 0;

    # читаем лог чанками
    CHUNKS: while (!eof($LOG_FH) and ++$chunk_counter<$controller->{max_chunks} ) {
        # ... и внутри чанка транзакциями обновляем БД
        my $chunk = $controller->get_next_chunk_from_log($LOG_FH)
            or last CHUNKS;
        $model->txn(sub {
            my %args = @_;
            $controller->parse_chunk($model => $chunk, @_);
        });
    };

    $controller->close_log($LOG_FH);
}
