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

our $d;

sub handle_request {
    my $self = shift;
    my $r = shift;
    my %args = (
        render => 'norender',
        @_
    );
    my $tt_template;
    my $tt_template_path;
    my $return = { data => {} };

    my ($method, $path, $content) = ($r->method, $r->uri->path, $r->content);

    my $tt = Template->new(TRIM => 1, ABSOLUTE => 1);

    if ($method eq 'GET' && $path eq "/") {
        $tt_template_path = lib::abs::path('../../templates/search.tt2');

    } elsif ($method eq 'POST' && $path eq "/search") {
        $tt_template_path = lib::abs::path('../../templates/search.tt2');

        my $json_text = $r->content;
        my $rdata = eval { decode_json($json_text) };
        if ($@ || !$rdata->{s}) {
            retrurn HTTP::Response->new(HTTP_BAD_REQUEST, "Invalid JSON")
        }
        my $email = $rdata->{s};
        if (!$email) {
            return HTTP::Response->new(HTTP_BAD_REQUEST, "Invalid request - nothing to search")
        }
        my $ids = $self->{model}->search_by_email_substring($email);

        # когда email-ы не найдены
        # это поведение надо отработать отдельно
        !@$ids and return HTTP::Response->new(HTTP_NOT_FOUND, "Emails not found");

        my @tables = qw/log message/;
        $return = { data => $self->{model}->get_rows_on_address_id(\@tables, $ids) };

        if (defined $return->{data}->[100]) {
            $return->{data}->[99]{continue} = 1;
            splice @{ $return->{data} }, 100, 1;
        };

        $args{render}='JSON' if (!$args{testit});

    } elsif ($method eq 'POST' && $path eq "/suggest") {
        $tt_template_path = lib::abs::path('../../templates/search.tt2');

        my $json_text = $r->content;
        my $rdata = eval { decode_json($json_text) };
        if ($@ || !$rdata->{s}) {
            retrurn HTTP::Response->new(HTTP_BAD_REQUEST, "Invalid JSON")
        }
        my $email = $rdata->{s};
        if (!$email) {
            retrurn HTTP::Response->new(HTTP_BAD_REQUEST, "Invalid request - nothing to search")
        }
        my $ids = $self->{model}->search_by_email_substring($email);

        # когда email-ы не найдены
        # это поведение надо отработать отдельно
        !@$ids and return HTTP::Response->new(HTTP_NOT_FOUND, "Emails not found");

        my @tables = qw/log message/;
        $return = { data => $self->{model}->get_emails_on_address_id($ids) };
        $args{render}='JSON' if (!$args{testit});

    } elsif ($method eq 'POST' && $path eq "/submit") {
        $return = {data => {} };
        $tt_template = "Received POST data: $content";
    } else {
        return HTTP::Response->new(RC_NOT_FOUND);
    }

    # рендер через Template::Toolkit
    if ($args{render} eq 'TT') {
        my $body = '';
        $tt->process( $tt_template_path ? $tt_template_path : \$tt_template, $return, \$body )
            or die $tt->error();

        my $resp = HTTP::Response->new(RC_OK, undef, undef, $tt_template_path ? $body : encode('UTF-8', $body));
        $resp->header('Content-Type' => 'text/html; charset=utf-8');
        return $resp;
    }
    if ($args{render} eq 'JSON') {
        my $body = encode_json($return);

        my $resp = HTTP::Response->new(RC_OK, undef, undef, $tt_template_path ? $body : encode('UTF-8', $body));
        $resp->header('Content-Type' => 'application/json; charset=utf-8');
        return $resp;
    }

    # возвращаем просто данные, если дошли до этой строки
    return $return;
}

sub new {
    my $pkg  = shift;
    my %args = (
        @_,
        LocalPort => 8080,
    );

    my $self = bless {  %args }, $pkg;
    $self->{model} //= GPBExim::get_model('SQLite3::File');

    return $self;
}

sub start {
    my $self = shift;

    $d = HTTP::Daemon->new(
        LocalAddr => '0.0.0.0',
        LocalPort => $self->{LocalPort} // 8080
    )
        || die "Can't start server: $!";
    warn "Сервер: ", $d->url, "\n";

    $SIG{INT} = sub { close($d) if $d; exit; };

    while (my $c = $d->accept) {
        while (my $r = $c->get_request) {
            my $resp = $self->handle_request($r, render => 'TT');
            $c->send_response($resp);
        }
        $c->close;
        undef($c);
    }
}

END { warn '--';
$d && warn "Bye...\n" && close($d)
};

1;