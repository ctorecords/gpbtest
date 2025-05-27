package GPBExim::Model;

use lib::abs '../../lib';
use uni::perl ':dumper';
use Try::Tiny;

use DBI;
use Search::Xapian;
use File::Path qw(remove_tree);

our $DBFILE;
our $SCHEMAFILE;

sub new {
    my $pkg = shift;
    my $self = bless { @_ }, $pkg;

    $self->init();
    $self->setup_dbh();

    return $self;
}

sub init { 
    my $self = shift;

    if ($self->{rm_xapian_db_on_init} and $self->{xapian_dir} and -d $self->{xapian_dir}) {
        delete $self->{xapian_db};
        remove_tree($self->{xapian_dir}, { error => \my $err });
        if (@$err) {
            warn "Failed to remove Xapian index at $self->{xapian_dir}: @$err\n";
        }
    };

    my $default_xapian_dir = lib::abs::path('../../temp/xapian');
    $self->{oidstart} = 0;
    $self->{xapian_dir} = $default_xapian_dir;
    $self->{xapian_db}  = Search::Xapian::WritableDatabase->new(
        $self->{xapian_dir}, 
        Search::Xapian::DB_CREATE_OR_OPEN
    );
    $self->{xapian_max_search_result} = 100_000_000;
    return $self;

}

sub setup_schema {
    my $self = shift;

    my $sql = do { local(@ARGV, $/) = $self->{schemafile}; <> }; # подгрузим sql
    $sql =~ s/--.+//g; # исключим комментарии
    $sql =~ s/\$OIDSTART/$self->{oidstart}/g; # подменим константу
    #print $sql, $/ x 2;
    $self->{dbh}->do($_) for split /;/, $sql;

    return $self;
}

sub setup_dbh {}

sub txn {
    my $self = shift;
    my $cb  = shift;
    $self->{dbh}->{RaiseError} = 1;

    try {
        $self->{dbh}->do('BEGIN TRANSACTION');
        $cb->();
        $self->{dbh}->do('COMMIT');
    } catch {
        warn "Transaction aborted because $_";
        eval { $self->{dbh}->do('ROLLBACK') };
    };
}

sub get_o_id {
    my $self = shift;

    if (!defined $self->{o_id}) {
        $self->{sth}{get_next_o_id}=$self->{dbh}->prepare_cached("select v from vars where n='o_id'");
        $self->{sth}{set_next_o_id}=$self->{dbh}->prepare_cached("update vars set v=? where n='o_id'");
        $self->{sth}{get_next_o_id}->execute;
        $self->{o_id} = $self->{sth}{get_next_o_id}->fetchrow_array;
    }
    return int($self->{o_id});
}

sub get_next_o_id {
    my $self = shift;

    $self->{o_id} //= $self->get_o_id();
    $self->{o_id}=int($self->{o_id})+1;
    $self->{sth}{set_next_o_id}->execute($self->{o_id});
    $self->{sth}{set_next_o_id}->finish;
    return $self->{o_id};
}

sub get_rows_on_address_id {
    my $self     = shift;
    my $tables   = shift;
    my $ids      = shift;
    my %args     = @_;

    my $return = $self->{dbh}->selectall_arrayref(
            join (' union ',
                map { qq{
                    select created, str, int_id, o_id, '$_' as t
                    from $_ where address_id in (@{[ join(', ', map { '?' } @$ids) ]})
                } } @$tables 
            ). ' order by int_id, o_id', 
            { Slice => {} },  map { @$ids } @$tables );

    $args{debug} && 
        warn dumper($return);
    return $return;
}

sub _add_xapian_ngrams {
    my $self = shift;
    my ($min, $max)  = (1, 5);

    my ($doc, $text, $prefix) = @_;
    $max = my $length = length($text);
    for my $n ($min .. $max) {
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
    my $doc = Search::Xapian::Document->new;
    $self->_add_xapian_ngrams($doc, $email, 'N');
    $doc->set_data($id);
    $self->{xapian_db}->add_document($doc);

    $self->{indexed_xapian_email}{$id} = $email;
}

sub search_by_email_substring {
    my $self      = shift;
    my $substring = shift;
    croak "substring is required" unless defined $substring;

    my $query = Search::Xapian::Query->new("N$substring");
    my $enquire = Search::Xapian::Enquire->new($self->{xapian_db});
    $enquire->set_query($query);

    my $mset = $enquire->get_mset(0, $self->{xapian_max_search_result});
    my %results;

    for my $match ($mset->items) {
        my $id = $match->get_document->get_data;
        $results{$id}=1;
    }

    return [keys %results];
}

sub DESTROY {
    my $self = shift;
    if ($self->{rm_xapian_db_on_destroy} and $self->{xapian_dir} and -d $self->{xapian_dir}) {
        delete $self->{xapian_db};
        remove_tree($self->{xapian_dir}, { error => \my $err });
        if (@$err) {
            warn "Failed to remove Xapian index at $self->{xapian_dir}: @$err\n";
        }
    };
}
1;