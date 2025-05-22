package GPBExim::Model::SQLite3::Memory;

use lib::abs '../../../../lib';
use uni::perl;
use parent 'GPBExim::Model::SQLite3';

sub init {
    my $self = shift;
    
    $self->SUPER::init(@_);

}



1;