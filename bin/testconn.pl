#!/usr/bin/env perl
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Parser;
use GPBExim::Config;
use GPBExim::Log;
use Cwd qw(abs_path);

my $cfg = GPBExim::Config->get();

log(debug => "Get model %s", $cfg->{db}{model_type});
log(info => "Checking DB cred ", {$cfg->{db}{model_type}=>$cfg->{db}});
GPBExim::get_model($cfg->{db}{model_type});

