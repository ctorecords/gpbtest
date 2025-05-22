# simple_server.pl (упрощённая логика)
use strict;
use warnings;
use lib::abs '../lib';
use GPBExim::View;

GPBExim::View->new(LocalPort => 8081)->start();