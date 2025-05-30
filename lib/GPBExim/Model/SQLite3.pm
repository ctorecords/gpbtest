package GPBExim::Model::SQLite3;

use lib::abs '../../../lib';
use uni::perl ':dumper';
use parent 'GPBExim::Model';

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{dbfile} = ':memory:';
    $self->{schemafile} //= lib::abs::path('../../../schema/SQLite3.sql');
}

sub setup_dbh {
    my $self = shift;
    $self->{dbh} = DBI->connect(qq{dbi:SQLite:dbname=}.$self->{dbfile}, "", "", { RaiseError => 1 });
}

sub sql_order_str { shift; my $field = shift; return sprintf('%s COLLATE BINARY', $field) }

1;