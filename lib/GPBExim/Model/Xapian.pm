package GPBExim::Model::Xapian;
use lib::abs '../../../lib';
use uni::perl ':dumper';
use GPBExim::Config;
use JSON::XS;
use Search::Xapian;
use File::Path qw(remove_tree);

sub new {
    my $pkg = shift;
    my $self = bless { @_ }, $pkg;

    $self->{cfg} = GPBExim::Config->get();

    if ($self->{rm_xapian_db_on_init} and $self->{cfg}{xapian}{path} and -d $self->{cfg}{xapian}{path}) {
        delete $self->{xapian_db};
        delete $self->{indexed_xapian_email};
        remove_tree($self->{cfg}{xapian}{path}, { error => \my $err });
        if (@$err) {
            warn "Failed to remove Xapian index at $self->{cfg}{xapian}{path}: @$err\n";
        }
    };
    $self->{xapian_db}  = Search::Xapian::WritableDatabase->new(
        $self->{cfg}{xapian}{path},
        Search::Xapian::DB_CREATE_OR_OPEN
    );
    $self->{xapian_max_search_result} = $self->{cfg}{xapian}{max_results};

    return $self;
}

sub _add_xapian_ngrams {
    my $self = shift;
    my ($min, $max)  = (3, 5);

    my ($doc, $text, $prefix) = @_;
    $max = my $length = length($text);
    for my $n ($self->{cfg}{xapian}{min} .. $max) {
        for my $i (0 .. $length - $n) {
            my $ngram = substr($text, $i, $n);
            $doc->add_term($prefix . $ngram);
        }
    }
}

sub index_address_at_xapian {
    my $self = shift;
    my ($email, $id) = @_;

    return if defined $self->{indexed_xapian_email}{$id};

    my $term = 'N' . $email;

    # Проверка через term_exists (безопасно)
    if ($self->{xapian_db}->term_exists($term)) {
        $self->{indexed_xapian_email}{$id} = $email;
        return;
    }

    my $doc = Search::Xapian::Document->new;
    $self->_add_xapian_ngrams($doc, $email, 'N');
    $doc->set_data(encode_json({ id => $id, email => $email }));

    $self->{xapian_db}->add_document($doc)
        or die "Can't add document for $email";

    $self->{indexed_xapian_email}{$id} = $email;
}

sub search_by_email_substring {
    my $self      = shift;
    my $substring = shift;
    my %args      = (
        limit => $self->{xapian_max_search_result},
        @_
    );
    croak "substring is required" unless defined $substring;

    my $query   = Search::Xapian::Query->new("N$substring");
    my $enquire = Search::Xapian::Enquire->new($self->{xapian_db});
    $enquire->set_query($query);

    my $mset = $enquire->get_mset(0, $args{limit});
    my %results;

    for my $match ($mset->items) {
        my $data = $match->get_document->get_data;
        my $obj  = decode_json($data);
        $results{$obj->{id}}=$obj->{email};
    }

    return \%results;
}

sub search_id_by_email_substring {
    my $self      = shift;
    my $substring = shift;
    croak "substring is required" unless defined $substring;
    my %args      = (
        limit => $self->{xapian_max_search_result},
        @_
    );

    my $results = $self->search_by_email_substring($substring, %args);
    return [sort keys %$results];
}

sub search_email_by_email_substring {
    my $self      = shift;
    my $substring = shift;
    croak "substring is required" unless defined $substring;
    my %args      = (
        limit => $self->{xapian_max_search_result},
        @_
    );

    my $results = $self->search_by_email_substring($substring, %args);
    return [sort values %$results];
}

sub destroy {
    my $self = shift;

    if ($self->{cfg}{xapian}{clear_db_on_destroy} and $self->{cfg}{xapian}{path} and -d $self->{cfg}{xapian}{path}) {
        delete $self->{xapian_db};
        delete $self->{indexed_xapian_email};
        remove_tree($self->{cfg}{xapian}{path}, { error => \my $err });
        if (@$err) {
            warn "Failed to remove Xapian index at $self->{cfg}{xapian}{path}: @$err\n";
        }
    };

}

1;