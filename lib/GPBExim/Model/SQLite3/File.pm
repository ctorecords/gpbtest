package GPBExim::Model::SQLite3::File;

use lib::abs '../../../../lib';
use DBI;

our $DBFILE = lib::abs::path('../../../../temp/sqlite3.db');

sub new {
    my $pkg = shift;

    return DBI->connect(qq{dbi:SQLite:dbname=$DBFILE}, "", "", { RaiseError => 1 });
}

1;