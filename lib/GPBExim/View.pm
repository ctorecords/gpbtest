package GPBExim::View;

use strict;
use warnings;
use HTTP::Daemon;
use HTTP::Response;
use HTTP::Status;
use uni::perl ':dumper';
use lib::abs '../../lib';
use GPBExim;
use Template;
use Encode;

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
            qw/message message_address message_bounce bounce_reasons log/
        } };
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