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
    my %args = (
        LocalPort => 8080,
        @_,
    );

    my $self = bless {  %args }, $pkg;
    $self->start(%args);

    return $self;
}

sub start {
    my $self = shift;

    my %args  = (
        model_type => 'MySQL',
        rm_xapian_db_on_destroy => 0,
        rm_xapian_db_on_init    => 0,
        clear_db_on_init        => 0,
        clear_db_on_destroy     => 0,
        @_
    );

    my $m = GPBExim::get_model($args{model_type},
        rm_xapian_db_on_destroy => $args{rm_xapian_db_on_destroy},
        rm_xapian_db_on_init    => $args{rm_xapian_db_on_init},
        clear_db_on_init        => $args{clear_db_on_init},
        clear_db_on_destroy     => $args{clear_db_on_destroy},
    )->setup_schema();
    my $v = GPBExim::View->new(model => $m);
    my $c = GPBExim::Controller->new();

    $d = HTTP::Daemon->new(
        LocalAddr => '0.0.0.0',
        LocalPort => $self->{LocalPort} // 8080
    )
        || die "Can't start server: $!";
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