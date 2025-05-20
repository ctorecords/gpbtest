use strict;
use warnings;
use lib::abs 'lib';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'GPBEximp',
    VERSION      => '0.01',
    LIBS         => [''],
    INC          => '',
    PREREQ_PM    => {
        'DBI'        => 0,
        'DBD::SQLite'=> 0,
        'Test::More'            => 0,
        'lib::abs'              => 0,
    },
    test => { TESTS => 't/*.t' },
);

