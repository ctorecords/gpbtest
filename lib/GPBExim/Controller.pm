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

    # получим список проиндексированных в Xapian e-mail адресов
    my $emails = $m->{xapian}->search_email_by_email_substring($email);
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

    # получим список проиндексированных в Xapian e-mail адресов
    my $ids = $m->{xapian}->search_id_by_email_substring($email);
    return $return if (!@$ids);

    # получим данные строчек log и message, связанных с этими адресами
    $return->{data} = $m->get_rows_on_address_id([qw/log message/], $ids,
        limit => $self->{cfg}{ui}{max_results}+1,
        %args
    );

    # если строчек больше лимита, то последний 101й элемент пометим
    if (defined $return->{data}->[$self->{cfg}{ui}{max_results}]) {
        $return->{data}->[$self->{cfg}{ui}{max_results}-1]{continue} = 1;
        splice @{ $return->{data} }, $self->{cfg}{ui}{max_results}, 1;
    };

    return $return;
}

sub root {
    my $self = shift;
    my $r    = shift;
    my $m    = shift;
    my %args = @_;

    $args{testit} && return { render => undef, data => {} };

    return { render => 'TT',  data => { max_results => $self->{cfg}{max_results} }, template => $self->{cfg}{ui}{template_path}  };
};

1;