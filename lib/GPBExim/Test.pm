package GPBExim::Test;

use Test::More;
use JSON::XS;

use uni::perl ':dumper';
use lib::abs '../../lib';
use GPBExim;
use GPBExim::Controller;
use GPBExim::View;
use HTTP::Request;
use JSON::XS;
use Encode qw(encode);

use Exporter 'import';
our @EXPORT_OK = qw(
    test_parse_line
    test_parse_chunk
    test_parse_logfile
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

    is_deeply(GPBExim::Controller->new()->parse_line($line), $hash, encode('UTF-8', $title) );
}

sub test_parse_chunk {
    my $title = shift;
    my $chunk = shift;
    my $hash  = shift;
    my %args  = (
        model_type => 'SQLite3::Memory',
        rm_xapian_db_on_destroy => 0,
        rm_xapian_db_on_init    => 0,
        @_
    );


    my $m = GPBExim::get_model($args{model_type},
        rm_xapian_db_on_destroy => $args{rm_xapian_db_on_destroy},
        rm_xapian_db_on_init    => $args{rm_xapian_db_on_init},
    )->setup_schema();
    my $v = GPBExim::View->new(model => $m);
    my $c = GPBExim::Controller->new();

    $c->parse_chunk($m => $chunk);

    my $message_address = $m->{dbh}->selectall_arrayref("select id, created, address, status from message_address", { Slice => {} });
    my %xemails = map { $_->{address} => { orig => [$_->{id}], found=> $m->search_by_email_substring($_->{address}) } } @$message_address;
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

}

sub test_parse_logfile {
    my $title    = shift;
    my $fname    = shift;
    my $search_expected = shift;
    my %args  = (
        model_type => 'SQLite3::Memory',
        rm_xapian_db_on_destroy=>1,
        rm_xapian_db_on_init => 1,
        rm_dbfile_on_init => 1,
        @_
    );

    my $m = GPBExim::get_model($args{model_type},
        rm_xapian_db_on_destroy => $args{rm_xapian_db_on_destroy},
        rm_xapian_db_on_init    => $args{rm_xapian_db_on_init},
        rm_dbfile_on_init       => $args{rm_dbfile_on_init},
    )->setup_schema();
    my $v = GPBExim::View->new(model => $m);
    my $c = GPBExim::Controller->new();

    $fname and $c->parse_logfile($fname => $m);

    for my $s (keys %$search_expected) {
        my $got = $v->handle_request(cq($s));
        is_deeply($got, $search_expected->{$s}, encode('UTF-8', "$title: $s"));
    }
}

sub test_search {
    my $title  = shift;
    my $chunk  = shift;
    my $search = shift;
    my $expected   = shift;
    my %args  = (
        model_type => 'SQLite3::Memory',
        rm_xapian_db_on_destroy => 0,
        rm_xapian_db_on_init    => 0,
        @_
    );

    my $m = GPBExim::get_model($args{model_type},
        rm_xapian_db_on_destroy => $args{rm_xapian_db_on_destroy},
        rm_xapian_db_on_init    => $args{rm_xapian_db_on_init},
    )->setup_schema();
    my $v = GPBExim::View->new(model => $m);
    my $c = GPBExim::Controller->new();

    $c->parse_chunk($m => $chunk);

    my $got = $v->handle_request(cq($search), testit => 1);
    is_deeply(
        $got,
        $expected,
        encode('UTF-8', $title),
    );
}


sub cq {
  my $search = shift;

  my $req = HTTP::Request->new(POST => '/search');
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json({ s => $search }));

  return $req;
}
