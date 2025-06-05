package GPBExim::Model::SQLite3;

use lib::abs '../../../lib';
use uni::perl ':dumper';
use parent 'GPBExim::Model';

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{path} ||= ':memory:';
    $self->{schemafile} ||= $self->{cfg}{db}{schema_path} // '';
}

sub setup_dbh {
    my $self = shift;
    $self->{dbh} = DBI->connect(qq{dbi:SQLite:dbname=}.$self->{path}, "", "", { RaiseError => 1 });
}

sub sql_order_str { shift; my $field = shift; return sprintf('%s COLLATE BINARY', $field) }

1;