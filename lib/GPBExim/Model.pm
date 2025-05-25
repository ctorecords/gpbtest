package GPBExim::Model;

use lib::abs '../../lib';
use uni::perl ':dumper';
use Try::Tiny;

use DBI;

our $DBFILE;
our $SCHEMAFILE;

sub new {
    my $pkg = shift;
    my $self = bless { @_ }, $pkg;

    $self->init();
    $self->setup_dbh();

    return $self;
}

sub init { }

sub setup_schema {
    my $self = shift;

    my $sql = do { local(@ARGV, $/) = $self->{schemafile}; <> }; # подгрузим sql
    $sql =~ s/--.+//g; # исключим комментарии
    $self->{dbh}->do($_) for split /;/, $sql;
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
    return $self->{o_id};
}

sub get_next_o_id {
    my $self = shift;

    $self->{o_id} //= $self->get_o_id();
    $self->{o_id}++;
    $self->{sth}{set_next_o_id}->execute($self->{o_id});
    $self->{sth}{set_next_o_id}->finish;
    return $self->{o_id};
}


1;