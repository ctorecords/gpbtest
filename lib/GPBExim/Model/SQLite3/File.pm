package GPBExim::Model::SQLite3::File;

use lib::abs '../../../../lib';
use uni::perl;
use parent 'GPBExim::Model::SQLite3';

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{dbfile} = lib::abs::path('../../../../temp/sqlite3.db');
    $self->{schemafile} //= lib::abs::path('../../../schema/SQLite3.sql');
}


1;