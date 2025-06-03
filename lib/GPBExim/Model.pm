package GPBExim::Model;

use lib::abs '../../lib';
use uni::perl ':dumper';
use Try::Tiny;

use DBI;
use JSON::XS;
use Scalar::Util::Numeric qw/isint/;
use GPBExim::Config;
use GPBExim::Model::Xapian;

sub new {
    my $pkg = shift;
    my $self = bless { @_ }, $pkg;

    $self->{cfg} = GPBExim::Config->get();
    $self->init(@_);
    $self->setup_dbh();

    return $self;
}

sub init {
    my $self = shift;

    $self->{xapian} = GPBExim::Model::Xapian->new;
    $self->{oidstart} = $self->{cfg}{xapian}{oid_start};

    return $self;

}

sub setup_schema {
    my $self = shift;

    my $sql = do {
        local(@ARGV, $/) = $self->{cfg}{db}{schema_path};
        <>;
    };

    $sql =~ s/--.+//g;                    # удалим SQL-комментарии
    $sql =~ s/\$OIDSTART/$self->{oidstart}/g;

    my $dbh     = $self->{dbh};
    my $schema  = $self->{cfg}{db}{name};
    my @stmts   = split /;/, $sql;

    my $pkg = ref($self);
    my $is_mysql = $self->{cfg}{db}{model_type} eq 'MySQL' ? 1 : 0;
    for my $stmt (@stmts) {
        $stmt =~ s/^\s+|\s+$//g;
        next unless $stmt;

        if ($is_mysql && $stmt =~ /^CREATE\s+INDEX\s+(\w+)\s+ON\s+(\w+)\s*\(/i) {
            my ($index_name, $table_name) = ($1, $2);

            my $exists = $dbh->selectrow_array(
                "SELECT COUNT(*) FROM information_schema.statistics
                 WHERE table_schema = ? AND table_name = ? AND index_name = ?",
                undef, $schema, $table_name, $index_name
            );

            if ($exists) {
                #warn "Index $index_name on $table_name already exists, skipping\n";
                next;
            } else {
                #warn "Creating index $index_name on $table_name\n";
            }
        }

        $dbh->do($stmt);
    }

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
    return [] if !@$ids;

    my %args     = @_;

    die "Limit is must by int" if defined ($args{limit}) && !isint($args{limit});
    my $limit = delete $args{limit} // $self->{cfg}{ui}{max_results} + 1;
    $limit =  $self->{cfg}{ui}{max_results} + 1 if $limit > $self->{cfg}{ui}{max_results} + 1;

    my $return = $self->{dbh}->selectall_arrayref(
            join (' union ',
                map { qq{
                    select created, str, int_id, o_id, '$_' as t
                    from $_ where address_id in (@{[ join(', ', map { '?' } @$ids) ]})
                } } @$tables
            ). " order by @{[$self->sql_order_str('int_id')]}, o_id asc limit $limit",
            { Slice => {} },  map { @$ids } @$tables );

    $args{debug} &&
        warn dumper($return);
    return $return;
}

sub sql_prepare {
    my $self = shift;

    my %_sth = (
        insert_log            => qq{ insert into log (created, int_id, str, address_id, o_id) values(?, ?, ?, ?, ?) },
        insert_message        => qq{ insert into message (id, created, int_id, str, address_id, o_id) values(?, ?, ?, ?, ?, ?) },
        insert_message_bounce => qq{ insert into message_bounce (created, int_id, address_id, str, o_id) values(?, ?, ?, ?, ?) },
        insert_address        => qq{ insert into message_address (created, address) values(?, ?) },

        get_message_by_id     => qq{ select id, created, int_id, str from message where id=? },
        get_address_by_email  => qq{ select id, created, address from message_address where address=? },

        get_message_and_log_by_int_id => qq{
            select
                created as created,
                address_id as address_id,
                str as str,
                o_id
            from log
            where  int_id=?

            union

            select
                created as created,
                address_id as address_id,
                str as str,
                o_id
            from message
            where  int_id=?

            order by o_id desc
        },
        get_log_by_all => qq{
            select
                log.created,
                log.int_id,
                log.str,
                log.address_id
            from log
            where  log.int_id=? and created=? and str=? and address_id=?
        },

    );

    $self->{sth}={ map { $_ => $self->{dbh}->prepare_cached($_sth{$_}) } keys %_sth };
}

sub DESTROY {
    my $self = shift;

    # зафинишим все стейтменты
    $_->finish() for (values %{$self->{sth}});

    $self->{xapian}->destroy();

}

1;