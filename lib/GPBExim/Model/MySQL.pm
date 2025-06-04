package GPBExim::Model::MySQL;

use lib::abs '../../../lib';
use uni::perl ':dumper';
use parent 'GPBExim::Model';
use Try::Tiny;

use DBI;
# CREATE DATABASE gpbexim CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

sub init {
    my $self = shift;
    my %args = ( %{$self->{cfg}{db}}, @_ );

    $self->SUPER::init();

    $args{dsn} = $self->{dsn} = "DBI:mysql:database=$args{name};host=$args{host};port=$args{port}";
    $self->{dbh} = DBI->connect( @args{qw/dsn user password/}, { RaiseError => 1, PrintError => 0 } )
        or die "Can't connect to DB: $DBI::errstr";

    $self->clear_all_tables if ($self->{clear_db_on_init});

    return $self;
}

sub clear_all_tables {
    my $self = shift;

    $self->{dbh}->do('SET FOREIGN_KEY_CHECKS = 0');
    for my $table (map {@$_} @{$self->{dbh}->selectall_arrayref("show tables")}) {
        $self->{dbh}->do("drop table $table");
    }
    $self->{dbh}->do('SET FOREIGN_KEY_CHECKS = 1');

}

sub txn {
    my $self = shift;
    my $cb  = shift;
    $self->{dbh}->{RaiseError} = 1;

    try {
        $self->{dbh}->do('START TRANSACTION');
        $cb->();
        $self->{dbh}->do('COMMIT');
    } catch {
        warn "Transaction aborted because $_";
        eval { $self->{dbh}->do('ROLLBACK') };
    };
}

sub sql_order_str { shift; my $field = shift; return sprintf('BINARY %s', $field) }

sub DESTROY {
    my $self = shift;

    if (my $super_destroy = $self->can('SUPER::DESTROY')) {
        $self->$super_destroy();
    }

    # Опционально — чистка БД
    if ($self->{cfg}{db}{clear_db_on_destroy}) {
        $self->clear_all_tables;
    }

}

1;
