package GPBExim::Model::SQLite3;

use lib::abs '../../../lib';
use uni::perl ':dumper';
use parent 'GPBExim::Model';

use GPBExim::Log;

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{path} ||= ':memory:';
    $self->{schema_path} ||= $self->{cfg}{db}{schema_path} // '';
}

sub setup_dbh {
    my $self = shift;
    $self->{dbh} = DBI->connect(qq{dbi:SQLite:dbname=}.$self->{path}, "", "", { RaiseError => 1 });
}

sub clear_all_tables {
    my $self = shift;

    log(debug => 'SQLite3 clearing all tables');

    $self->{dbh}->do('PRAGMA foreign_keys = OFF');
    for my $table (map {@$_} @{$self->{dbh}->selectall_arrayref(q{SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'})}) {
        $self->{dbh}->do("DROP TABLE IF EXISTS \"$table\"");
    }
    $self->{dbh}->do('PRAGMA foreign_keys = ON');
}


sub sql_order_str { shift; my $field = shift; return sprintf('%s COLLATE BINARY', $field) }

1;