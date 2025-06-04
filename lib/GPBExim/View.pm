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
        my $tt = Template->new(TRIM => 1, ABSOLUTE => 1);
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

sub render {
    my $self = shift;
    my $data = shift;
    my %args = @_;

    # если пришёл готовый HTTP::Response, просто его возвращаем
    if ($data->{render} eq 'HTTP::Response') {
        return $data->{data};
    }

    # рендер через Template::Toolkit
    if ($data->{render} eq 'TT') {
        my $tt = Template->new(TRIM => 1, ABSOLUTE => 1);
        my $body = '';
        $tt->process( $data->{template}, $data, \$body )
            or die $tt->error();

        my $resp = HTTP::Response->new(RC_OK, undef, undef, $body);
        $resp->header('Content-Type' => 'text/html; charset=utf-8');
        return $resp;
    }

    # рендер JSON
    if ($data->{render} eq 'JSON') {
        my $body = encode_json($data);

        my $resp = HTTP::Response->new(RC_OK, undef, undef, encode('UTF-8', $body));
        $resp->header('Content-Type' => 'application/json; charset=utf-8');
        return $resp;
    }

    # возвращаем просто данные, если дошли до этой строки
    return { data => $data->{data} };
}


1;