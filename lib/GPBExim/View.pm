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
        $tt_template_path = lib::abs::path('../../templates/start.tt2');
        $return = { data => {
            map { $_ =>  $self->{model}{dbh}->selectall_arrayref("select count(*) as ".$_."_count from $_", { Slice => {} })->[0]{$_.'_count'} }
            qw/message message_address message_bounce log/
        } };
    } elsif ($method eq 'GET' && $path eq "/search") {
        $tt_template_path = lib::abs::path('../../templates/searcg.tt2');

    } elsif ($method eq 'POST' && $path eq "/search") {
        $tt_template_path = lib::abs::path('../../templates/searcg.tt2');

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
        $return = { data => $self->{model}->get_rows_on_address_id(\@tables, $ids) };

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

        return HTTP::Response->new(RC_OK, undef, undef, $tt_template_path ? $body : encode('UTF-8', $body));
    }

    # возвращаем просто данные, если дошли до этой строки
    return $return;
}

sub new {
    my $pkg  = shift;
    my %args = (
        LocalPort => 8080,
        @_
    );

    my $self = bless {  %args }, $pkg;
    $self->{model} //= GPBExim::get_model('SQLite3::File');

    return $self;
}

sub start {
    my $self = shift;

    my $d = HTTP::Daemon->new(LocalPort => $self->{LocalPort} // 8080)
        || die "Can't start server: $!";
    warn "Сервер: ", $d->url, "\n";

    while (my $c = $d->accept) {
        while (my $r = $c->get_request) {
            my $resp = $self->handle_request($r, render => 'TT');
            $c->send_response($resp);
        }
        $c->close;
        undef($c);
    }
}

1;