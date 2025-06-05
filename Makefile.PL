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
        'DBD::mysql' => 0, # не забыть "apt-get install libmysqlclient-dev"
        'Test::More'            => 0,
        'lib::abs'              => 0,
        'uni::perl'             => 0,
        'Try::Tiny'             => 0,
        'Template'              => 0, 
        'Search::Xapian'        => 0, # не забыть "apt-get install libxapian-dev"
        'HTTP::Status'          => 0,
        'Scalar::Util::Numeric' => 0,
        'Config::Any'           => 0,
        'Getopt::Long'          => 0,
        'LWP::UserAgent'        => 0,
        'HTTP::Request::Common' => 0,
        
    },
    test => { TESTS => 't/*.t' },
);

