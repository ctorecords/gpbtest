use strict;
use warnings;
use lib::abs 'lib';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'GPBExim',
    VERSION      => '0.01',
    LIBS         => [''],
    INC          => '',
    PREREQ_PM    => {
        'DBI'        => 0,
        'DBD::SQLite'=> 0,
        'Test::More'            => 0,
        'lib::abs'              => 0,
        'uni::perl'             => 0,
        'Try::Tiny'             => 0,
        'Template'              => 0, 
        'Search::Xapian'        => 0, # не забыть "apt-get install libxapian-dev"
    },
    test => { TESTS => 't/*.t' },
);

