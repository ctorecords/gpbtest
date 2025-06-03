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

    my %args  = (
        model_type              => $self->{cfg}{db}{model_type},

        rm_xapian_db_on_destroy => $self->{cfg}{xapian}{clear_db_on_destroy},
        rm_xapian_db_on_init    => $self->{cfg}{xapian}{clear_db_on_init},

        clear_db_on_destroy     => $self->{cfg}{db}{clear_db_on_destroy},
        clear_db_on_init        => $self->{cfg}{db}{clear_db_on_init},

        server_host             => $self->{cfg}{ui}{server_host},
        server_port             => $self->{cfg}{ui}{server_port},

        @_
    );

    my %connect = (
        LocalAddr => delete $args{server_host},
        LocalPort => delete $args{server_port},
    );

    my $m = GPBExim::get_model(delete $args{model_type}, %args);
    my $v = GPBExim::View->new(model => $m);
    my $c = GPBExim::Controller->new();

    $d = HTTP::Daemon->new( %connect )
        || die "Can't start server on $connect{LocalAddr}:$connect{LocalPort}: $!";

    warn "Сервер: ", $d->url, "\n";

    $SIG{INT} = sub { warn "Bye...\n"; close($d) if $d; exit; };

    while (my $_c = $d->accept) {
        while (my $r = $_c->get_request) {
            my $resp = $v->handle_request($r, model => $m, render => 'TT');
            $_c->send_response($resp);
        }
        $_c->close;
        undef($_c);
    }
}

DESTROY { warn "Bye...\n"; close($d) if $d };

1;