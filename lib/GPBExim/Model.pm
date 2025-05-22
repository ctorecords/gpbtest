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



1;