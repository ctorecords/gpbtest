package GPBExim::App;

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Status;
use uni::perl ':dumper';
use HTTP::Status qw(:constants);

use lib::abs '../../lib';
use GPBExim;
use GPBExim::Controller;
use GPBExim::View;
use GPBExim::Log;

our $d;

sub new {
    my $pkg  = shift;
    my $args = GPBExim::Config->apply_args(
        [qw/ui/],
        @_
    );

    my $self = bless {
        cfg => GPBExim::Config->get(),
        %{$args->{x}{ui}},
    }, $pkg;
    return $self;
}

sub start {
    my $self = shift;

    my $cfg  = $self->{cfg};
    my $args = GPBExim::Config->apply_args(
        [qw/db xapian ui/],
        @_
    );

    my $silent = delete $args->{x}{ui}{silent};

    my %connect = (
        LocalAddr => delete $args->{x}{ui}{server_host},
        LocalPort => delete $args->{x}{ui}{server_port},
    );

    $self->init(map { %{$args->{raw}{$_}} }  qw/db xapian/);

    $d = HTTP::Daemon->new( %connect )
        || die "Can't start server on $connect{LocalAddr}:$connect{LocalPort}: $!";

    warn "Сервер: ", $d->url, "\n" if !$silent;

    $SIG{INT} = sub { !$silent and warn "Bye...\n"; close($d) if $d; exit; };

    while (my $_c = $d->accept) {
        while (my $r = $_c->get_request) {
            log(debug => "appp -> start -> request handle: ", {args_ui=>$args->{raw}{ui}});
            my $data = $self->handle_request($r, %{$args->{raw}{ui}});
            my $resp = $self->{view}->render($data);
            $_c->send_response($resp);
        }
        $_c->close;
        undef($_c);
    }
}

sub init {
    my $self = shift;
    my %args = @_;
    $self->{model}      //= GPBExim::get_model(delete $args{db__model_type}, %args);
    $self->{controller} //= GPBExim::Controller->new();
    $self->{view}       //= GPBExim::View->new();

    return $self;
}

sub handle_request {
    my $self = shift;
    my $r = shift;
    my %args = @_;

    my $m = $self->{model};
    my $return = { data => {} };

    my ($method, $path, $content) = ($r->method, $r->uri->path, $r->content);

    log(debug => "Webserver [$method] $path");
    log(debug => "handle_request: ", {args=>\%args});
    if ($method eq 'GET' && $path eq "/") {
        $return = $self->{controller}->root($r, $self->{model}, %args);
    } elsif ($method eq 'POST' && $path eq "/search") {
        $return = $self->{controller}->search($r, $self->{model}, %args);
    } elsif ($method eq 'POST' && $path eq "/suggest") {
        $return = $self->{controller}->suggest($r, $self->{model}, %args);
    } elsif (!$args{testit}) {
        $return = { render => 'HTTP::Response', data => HTTP::Response->new(RC_NOT_FOUND) };
    }

    return $return;
}

1;