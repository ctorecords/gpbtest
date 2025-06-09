#!/usr/bin/env perl
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Parser;
use GPBExim::Config;
use GPBExim::Log;
use Cwd qw(abs_path);

my $cfg = GPBExim::Config->get();
my $model;
my $parser;

log(debug => "Get model %s", $cfg->{db}{model_type});
$model = GPBExim::get_model($cfg->{db}{model_type});

