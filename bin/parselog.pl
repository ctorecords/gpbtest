use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Controller;

my $model;
my $controller;

$model = GPBExim::get_model('SQLite3::File'); $model->setup_schema();
$controller = GPBExim::Controller->new();


if (my $LOG_FH = $controller->open_log(lib::abs::path('../temp/maillog'))) {
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
undef $model, $controller;
