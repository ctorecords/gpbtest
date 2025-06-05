package GPBExim::TestHelper;

use Test::More;
use JSON::XS;

use uni::perl ':dumper';
use lib::abs '../../../lib';
use GPBExim;
use GPBExim::Controller;
use GPBExim::Parser;
use GPBExim::View;
use GPBExim::Config;
use GPBExim::App;
use HTTP::Request;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Time::HiRes qw(sleep);
use POSIX qw(:sys_wait_h);
use JSON::XS;
use Encode qw(encode);
use IO::Socket::INET;

use Exporter 'import';
our @EXPORT_OK = qw(
    test_parse_line
    test_parse_chunk
    test_search_in_parsed_logfile
    test_live_search_in_parsed_logfile
    test_search
    cq
);

sub test_parse_line {
    my $title = shift;
    my $line  = shift;
    my $hash  = shift;
    my %args  = (
        @_
    );

    is_deeply(GPBExim::Parser->new()->parse_line($line), $hash, encode('UTF-8', $title) );
}

sub test_parse_chunk {
    my $title = shift;
    my $chunk = shift;
    my $hash  = shift;
    my $cfg = GPBExim::Config->get();
    my %args = (
        model_type => $cfg->{db}{model_type},
        db__clear_db_on_init        => $cfg->{db}{clear_db_on_init},
        db__clear_db_on_destroy     => $cfg->{db}{clear_db_on_destroy},
        xapian__clear_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        xapian__clear_db_on_init    => $cfg->{xapian}{clear_db_on_init},
        xapian__path                => $cfg->{xapian}{path},
        xapian__min                 => $cfg->{xapian}{min},
        xapian__max_results         => $cfg->{xapian}{max_results},
        @_
    );
    my $model_type = delete $args{model_type};
    my %args_db  = (
        clear_db_on_init            => $args{db__clear_db_on_init},
        clear_db_on_destroy         => $args{db__clear_db_on_destroy},
    );
    my %args_xapian  = (
        clear_db_on_destroy         => $args{xapian__clear_db_on_destroy},
        clear_db_on_init            => $args{xapian__clear_db_on_init},
        path                        => $args{xapian__path},
        min                         => $args{xapian__min},
        max_results                 => $args{xapian__max_results},
    );

    my $m = GPBExim::get_model($model_type => %args_db)->setup_schema();
    my $x = GPBExim::get_model(Xapian      => %args_xapian, debug => 1);
    my $v = GPBExim::View->new(model => $m);
    my $p = GPBExim::Parser->new();

    $p->parse_chunk($m => $chunk);

    my $message_address = $m->{dbh}->selectall_arrayref("select id, created, address from message_address", { Slice => {} });
    my %xemails = map { $_->{address} => { orig => [$_->{id}], found=> $x->search_id_by_email_substring($_->{address}) } } @$message_address;
    is_deeply($xemails{$_}{orig}, $xemails{$_}{found}, encode('UTF-8', qq{Check xapian index for "$_" ($title)}))
        for (keys %xemails);

    # перечень таблиц для сравнения
    my @tables = qw/
        message
        message_address
        message_bounce
        log
    /;
    my @not_exists_tables = grep {!defined $hash->{$_}} @tables;
    is_deeply(
        {
            message         => $m->{dbh}->selectall_arrayref("select id, created, int_id, str, status, address_id, o_id from message order by o_id", { Slice => {} }),
            message_address => $message_address,
            message_bounce  => $m->{dbh}->selectall_arrayref("select created, int_id, address_id, o_id, str from message_bounce order by o_id", { Slice => {} }),
            log             => $m->{dbh}->selectall_arrayref("select created, int_id, str, address_id, o_id from log order by o_id", { Slice => {} }),
        },
        {
            %$hash,
            map { $_ => [] } @not_exists_tables  # если во входящем хеше таблица опущена, считаем, что данные по ней должны прийти пустыми
        },
        encode('UTF-8', $title)
    );
    $x->reset;

}

sub test_search_in_parsed_logfile {
    my $title    = shift;
    my $fname    = shift;
    my $search_expected = shift;
    my $cfg = GPBExim::Config->get();
    my %args = (
        model_type => $cfg->{db}{model_type},
        db__clear_db_on_init        => $cfg->{db}{clear_db_on_init},
        db__clear_db_on_destroy     => $cfg->{db}{clear_db_on_destroy},
        db__schema_path             => $cfg->{db}{schema_path},
        xapian__clear_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        xapian__clear_db_on_init    => $cfg->{xapian}{clear_db_on_init},
        xapian__path                => $cfg->{xapian}{path},
        xapian__min                 => $cfg->{xapian}{min},
        xapian__max_results         => $cfg->{xapian}{max_results},
        @_
    );

    (my $app = GPBExim::App->new()->init(%args))->{model}->setup_schema;
    $fname and GPBExim::Parser->new()->parse_logfile($fname => $app->{model});

    for my $s (keys %$search_expected) {
        my $got = $app->handle_request(cq($s), xdebug=>1);
        is_deeply($got, $search_expected->{$s}, encode('UTF-8', "$title: $s"));
    }
}

sub get_free_port {
    my $cfg = GPBExim::Config->get();
    my $sock = IO::Socket::INET->new(
        Proto     => 'tcp',
        LocalAddr => $cfg->{ui}{server_host},
        Listen    => 1,
        Reuse     => 1,
    ) or die "Не удалось открыть временный сокет: $!";
    my $port = $sock->sockport;
    $sock->close;
    return $port;
}

sub server_is_up {
    my ($host, $port) = @_;
    IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => 0.2,
    );
}


sub test_live_search_in_parsed_logfile {
    my $title    = shift;
    my $fname    = shift;
    my $search_expected = shift;
    my $cfg = GPBExim::Config->get();
    my %args = (
        model_type => $cfg->{db}{model_type},
        db__clear_db_on_init        => $cfg->{db}{clear_db_on_init},
        db__clear_db_on_destroy     => $cfg->{db}{clear_db_on_destroy},
        db__schema_path             => $cfg->{db}{schema_path},
        xapian__clear_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        xapian__clear_db_on_init    => $cfg->{xapian}{clear_db_on_init},
        xapian__path                => $cfg->{xapian}{path},
        xapian__min                 => $cfg->{xapian}{min},
        xapian__max_results         => $cfg->{xapian}{max_results},
        @_
    );

    (my $app = GPBExim::App->new()->init(%args))->{model}->setup_schema;
    $fname and GPBExim::Parser->new()->parse_logfile($fname => $app->{model});
    my $port = get_free_port();
    my $host = $cfg->{ui}{server_host};
    my $pid;
    $pid = fork();
    if (!defined $pid) {
        die "Не удалось сделать fork: $!";
    }
    elsif($pid == 0) {
        $SIG{INT} = sub { exit(0) };
        $app->start(
            server_port => $port,
            server_host => $host,
            silent => 1,
        );
        exit 0;
    }
    sleep 0.3 until server_is_up($host, $port);
    my $ua = LWP::UserAgent->new(timeout => 2);

    for my $handle (qw/search suggest/) {
        for my $s ( grep { $search_expected->{$_}{$handle} } keys %$search_expected ) {
            my $req_json = encode_json({ s => $s });
            my $url = "http://$host:$port/$handle";
            my $res = $ua->request(cq($s, $url));

            # тест живого сервера
            ok($res->is_success, encode('UTF-8', "Ответ на запрос '$req_json' от сервера $url получен"));
            is_deeply(decode_json($res->decoded_content), $search_expected->{$s}{$handle}, encode('UTF-8', "$title (live server - $handle): $s"));

            # тест модели
            is_deeply($app->handle_request(cq($s, "/$handle"), xdebug=>1), $search_expected->{$s}{$handle}, encode('UTF-8', "$title (model - $handle): $s"));
        }
    }

    kill 'INT', $pid;
    waitpid($pid, 0);
}

sub test_search {
    my $title  = shift;
    my $chunk  = shift;
    my $search = shift;
    my $expected   = shift;
    my $cfg = GPBExim::Config->get();
    my %args = (
        model_type => $cfg->{db}{model_type},
        db__clear_db_on_init        => $cfg->{db}{clear_db_on_init},
        db__clear_db_on_destroy     => $cfg->{db}{clear_db_on_destroy},
        xapian__clear_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        xapian__clear_db_on_init    => $cfg->{xapian}{clear_db_on_init},
        xapian__path                => $cfg->{xapian}{path},
        xapian__min                 => $cfg->{xapian}{min},
        xapian__max_results         => $cfg->{xapian}{max_results},
        @_
    );

    (my $app = GPBExim::App->new()->init(%args))->{model}->setup_schema;
    GPBExim::Parser->new()->parse_chunk($app->{model} => $chunk, xdebug => 1);

    my $got = $app->handle_request(cq($search), xdebug => 1);
    is_deeply(
        $got,
        $expected,
        encode('UTF-8', $title),
    );
}


sub cq {
  my $search = shift;
  my $handle = shift;

  my $req = HTTP::Request->new(POST => ($handle || '/search'));
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json({ s => $search }));

  return $req;
}
