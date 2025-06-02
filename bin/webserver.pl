use strict;
use warnings;
use lib::abs '../lib';
use GPBExim::App;
use GPBExim::Config;

my $cfg = GPBExim::Config->get();

GPBExim::App->new(LocalPort => $cfg->{ui}{server_port})->start();