package GPBExim::Model::SQLite3::File;

use lib::abs '../../../../lib';
use uni::perl ':dumper';
use parent 'GPBExim::Model::SQLite3';

sub init {
    my $self = shift;
    my %args = (
        @_
    );

    $self->SUPER::init(@_);

    $self->{dbfile} = lib::abs::path('../../../../temp/sqlite3.db');
    $self->{schemafile} //= lib::abs::path('../../../schema/SQLite3.sql');

    if ($self->{rm_dbfile_on_init} and -e $self->{dbfile}) {
        unlink $self->{dbfile} or warn "Failed to remove file $self->{dbfile}: $!";
    }

    return $self;
}


1;