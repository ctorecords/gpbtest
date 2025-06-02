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

    my $self = bless {  @_ }, $pkg;
    $self->{cfg} = GPBExim::Config->get();
    $self->start;

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
    );

    my $m = GPBExim::get_model($args{model_type} // $self->{cfg}{db}{model_type}, %args)->setup_schema();
    my $v = GPBExim::View->new(model => $m);
    my $c = GPBExim::Controller->new();

    my %connect = (
        LocalAddr => $self->{LocalHost} // $self->{cfg}{ui}{server_host},
        LocalPort => $self->{LocalPort} // $self->{cfg}{ui}{server_port}
    );
    $d = HTTP::Daemon->new( %connect )
        || die "Can't start server on $connect{connect}:$connect{LocalPort}: $!";

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