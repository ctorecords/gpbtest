package GPBExim::Model::SQLite3::Memory;

use lib::abs '../../../../lib';
use DBI;

sub new {
    my $pkg = shift;

    return DBI->connect(qq{dbi:SQLite:dbname=:memory:}, "", "", { RaiseError => 1 });
}

1;