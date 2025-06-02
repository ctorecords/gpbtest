package GPBExim::Model::MySQL;

use lib::abs '../../../lib';
use uni::perl ':dumper';
use parent 'GPBExim::Model';
use Try::Tiny;

use DBI;
# CREATE DATABASE gpbexim CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

sub init {
    my $self = shift;
    my %args = (
        @_
    );

    $self->SUPER::init(@_);

    $self->{host}     //= $self->{cfg}{db}{host};
    $self->{port}     //= $self->{cfg}{db}{port};
    $self->{user}     //= $self->{cfg}{db}{user};
    $self->{password} //= $self->{cfg}{db}{password};
    $self->{dbname}   //= $self->{cfg}{db}{name};
    $self->{schemafile} //= $self->{cfg}{db}{schema_path};

    # DSN формируется из параметров
    $self->{dsn} = "DBI:mysql:database=$self->{dbname};host=$self->{host};port=$self->{port}";

    # Подключение к БД
    $self->{dbh} = DBI->connect(
        $self->{dsn},
        $self->{user},
        $self->{password},
        {
            RaiseError => 1,
            PrintError => 0,
            mysql_enable_utf8mb4 => 1,
            mysql_socket => undef,
        }
    ) or die "Can't connect to DB: $DBI::errstr";

    # Опционально — очистка всех таблиц
    if ($self->{clear_db_on_init}) {
        $self->clear_all_tables;
    };

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

    # Опционально — удаление файла БД
    if ($self->{cfg}{db}{clear_db_on_destroy}) {
        $self->clear_all_tables;
    }

}

1;
