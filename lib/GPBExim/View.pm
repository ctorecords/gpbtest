package GPBExim::View;

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Status;
use uni::perl ':dumper';
use Template;
use Encode;
use HTTP::Status qw(:constants);
use JSON::XS;

use lib::abs '../../lib';
use GPBExim;
use GPBExim::Config;

sub new {
    my $pkg  = shift;
    my %args = (
        @_,
    );

    my $self = bless {  %args }, $pkg;
    $self->{cfg} = GPBExim::Config->get();

    return $self;
}

sub handle_request {
    my $self = shift;
    my $r = shift;
    my %args = @_;

    my $m = $self->{model};
    my $return = { data => {} };

    my ($method, $path, $content) = ($r->method, $r->uri->path, $r->content);

    my $tt = Template->new(TRIM => 1, ABSOLUTE => 1);

    if ($method eq 'GET' && $path eq "/") {
        $return = $self->root($r, $m);
    } elsif ($method eq 'POST' && $path eq "/search") {
        $return = $self->search($r, $m);
    } elsif ($method eq 'POST' && $path eq "/suggest") {
        $return = $self->suggest($r, $m);
    } elsif (!$args{testit}) {
        $return = { render => 'HTTP::Response', data => HTTP::Response->new(RC_NOT_FOUND) };
    }

    # вернём данные, если находимся в режиме теста
    $args{testit} && return { data => $return->{data} };

    # если пришёл готовый HTTP::Response, просто его возвращаем
    if ($return->{render} eq 'HTTP::Response') {
        return $return->{data};
    }

    # рендер через Template::Toolkit
    if ($return->{render} eq 'TT') {
        my $body = '';
        $tt->process( $return->{template}, $return, \$body )
            or die $tt->error();

        my $resp = HTTP::Response->new(RC_OK, undef, undef, $body);
        $resp->header('Content-Type' => 'text/html; charset=utf-8');
        return $resp;
    }

    # рендер JSON
    if ($return->{render} eq 'JSON') {
        my $body = encode_json($return);

        my $resp = HTTP::Response->new(RC_OK, undef, undef, encode('UTF-8', $body));
        $resp->header('Content-Type' => 'application/json; charset=utf-8');
        return $resp;
    }

    # возвращаем просто данные, если дошли до этой строки
    return { data => $return->{data} };
}

sub suggest {
    my $self = shift;
    my $r    = shift;
    my $m    = shift;
    my %args = @_;

    my $return = { data => [] };
    $return->{render} = 'JSON' if (!$args{testit});

    # получим входной запрос
    my $rdata = eval { decode_json($r->content) };
    return $return if ($@ || !$rdata->{s});

    # получим поисковую строку по e-mail
    my $email = $rdata->{s}
        or return $return;

    # получим список проиндексированных в Xapian e-mail адресов
    my $emails = $m->{xapian}->search_email_by_email_substring($email);
    return $return if (!@$emails);

    push @{$return->{data}}, {address => $_} for @$emails;

    return $return;

}

sub search {
    my $self = shift;
    my $r    = shift;
    my $m    = shift;
    my %args = @_;

    my $return = { data => [] };
    $return->{render} = 'JSON' if (!$args{testit});

    # получим входной запрос
    my $rdata = eval { decode_json($r->content) };
    return $return if ($@ || !$rdata->{s});

    # получим поисковую строку по e-mail
    my $email = $rdata->{s}
        or return $return;

    # получим список проиндексированных в Xapian e-mail адресов
    my $ids = $m->{xapian}->search_id_by_email_substring($email);
    return $return if (!@$ids);

    # получим данные строчек log и message, связанных с этими адресами
    $return->{data} = $m->get_rows_on_address_id([qw/log message/], $ids,
        limit => $self->{cfg}{ui}{max_results}+1);

    # если строчек больше лимита, то последний 101й элемент пометим
    if (defined $return->{data}->[$self->{cfg}{ui}{max_results}]) {
        $return->{data}->[$self->{cfg}{ui}{max_results}-1]{continue} = 1;
        splice @{ $return->{data} }, $self->{cfg}{ui}{max_results}, 1;
    };

    return $return;
}

sub root {
    my $self = shift;
    my $r    = shift;
    my $m    = shift;
    my %args = @_;

    $args{testit} && return { render => undef, data => {} };

    return { render => 'TT',  data => { max_results => $self->{cfg}{max_results} }, template => $self->{cfg}{ui}{template_path}  };
};



1;