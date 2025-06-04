package GPBExim::Controller;
use uni::perl ':dumper';
use lib::abs '../../lib';
use GPBExim::Config;
use JSON::XS;


sub new {
    my $pkg = shift;
    my $self = bless {
        cfg => GPBExim::Config->get(),

        @_
    }, $pkg;

    return $self;
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

    # получим список e-mail адресов
    my $emails = $m->search_email_by_substr($email);
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

    # получим список строчек log и message, связанных с $email
    $return->{data} = $m->search_rows_by_substr($email) // [];

    return $return;
}

sub root {
    my $self = shift;
    my $r    = shift;
    my $m    = shift;
    my %args = @_;

    $args{testit} && return { render => undef, data => {} };

    return { render => 'TT',  data => { max_results => $self->{cfg}{ui}{max_results} }, template => $self->{cfg}{ui}{template_path}  };
};

1;