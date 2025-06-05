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

our $d;

sub new {
    my $pkg  = shift;

    my $self = bless {
        cfg => GPBExim::Config->get(),
    }, $pkg;
    return $self;
}

sub start {
    my $self = shift;

    my $cfg  = $self->{cfg};
    my %args  = (
        silent                  => 0,
        model_type              => $self->{cfg}{db}{model_type},

        db__clear_db_on_init    => $cfg->{db}{clear_db_on_init},
        db__clear_db_on_destroy => $cfg->{db}{clear_db_on_destroy},
        db__schema_path         => $cfg->{db}{schema_path},
        db__path                => $cfg->{db}{path} // '',

        xapian__clear_db_on_destroy => $cfg->{xapian}{clear_db_on_destroy},
        xapian__clear_db_on_init => $cfg->{xapian}{clear_db_on_init},
        xapian__path            => $cfg->{xapian}{path},
        xapian__min             => $cfg->{xapian}{min},
        xapian__max_results     => $cfg->{xapian}{max_results},

        server_host             => $self->{cfg}{ui}{server_host},
        server_port             => $self->{cfg}{ui}{server_port},

        @_
    );
    my $silent = delete $args{silent};

    my %connect = (
        LocalAddr => delete $args{server_host},
        LocalPort => delete $args{server_port},
    );

    $self->init(%args);

    $d = HTTP::Daemon->new( %connect )
        || die "Can't start server on $connect{LocalAddr}:$connect{LocalPort}: $!";

    warn "Сервер: ", $d->url, "\n" if !$silent;

    $SIG{INT} = sub { !$silent and warn "Bye...\n"; close($d) if $d; exit; };

    while (my $_c = $d->accept) {
        while (my $r = $_c->get_request) {
            my $data = $self->handle_request($r);
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
    $self->{model}      //= GPBExim::get_model(delete $args{model_type}, %args);
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

#DESTROY { my $self = shift; warn "Bye...\n"; close($d) if $d };

1;