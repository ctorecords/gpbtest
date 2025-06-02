#!/usr/bin/env perl
use strict;
use warnings;
use lib::abs '../lib';
use uni::perl;
use GPBExim::App;
use GPBExim::Config;
use Getopt::Long;

my $port;

GetOptions(
    'p|port=i' => \$port,
) or die "Использование: $0 [-p порт]\n";

my $cfg = GPBExim::Config->get();

# Используем переданный порт или порт из конфига
warn "Использование: $0 [-p порт]\n";
$port //= $cfg->{ui}{server_port};

die "Не задан порт: ни в конфиге, ни в параметре -p" unless $port;

GPBExim::App->new(LocalPort => $port)->start();