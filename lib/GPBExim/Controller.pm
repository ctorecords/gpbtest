package GPBExim::Controller;
use uni::perl ':dumper';
use lib::abs '../../lib';
use GPBExim::Config;
use GPBExim::Log;
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
    log(debug => "Suggest for '$email'");

    # получим список e-mail адресов
    my $emails = $m->search_email_by_substr($email);
    return $return if (!@$emails);
    log(debug => "Found for '$email' @{[$#$emails+1]} emails");

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
    log(debug => "Search for '$email'");
    log(debug => {args=>\%args});

    # флаг "включить bounce"
    my $include_bounce = (defined $rdata->{include_bounce} and $rdata->{include_bounce} > 0) ? 1 : 0;

    # получим список строчек log и message, связанных с $email
    $return->{data} = $m->search_rows_by_substr($email, include_bounce => $include_bounce, %args) // [];
    my $count = @{$return->{data}};
    log(debug => "Found for '$email' $count rows");

    return $return;
}

sub root {
    my $self = shift;
    my $r    = shift;
    my $m    = shift;
    my %args = @_;

    $args{testit} && return { render => undef, data => {} };
    my $data = { max_results => $args{ui__max_results} };
    log(debug => "root ", { data => $data, args => \%args });

    return { render => 'TT',  data => $data, template => $args{ui__template_path}  };
};

1;