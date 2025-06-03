#!/usr/bin/env perl
use strict;
use warnings;
use lib::abs '../lib';
use uni::perl;
use GPBExim::App;
use GPBExim::Config;
use Getopt::Long;

my ($port, $host);

GetOptions(
    'p|port=i' => \$port,
    'h|host=s' => \$host,
) or die "Использование: $0 [-h host] [-p port]\n";

my $cfg = GPBExim::Config->get();

# Используем переданный порт или порт из конфига
warn "Использование: $0 [-h host] [-p port]\n";
$port //= $cfg->{ui}{server_port};
$host //= $cfg->{ui}{server_host};

die "Не задан хост: ни в конфиге, ни в параметре -h" unless $port;
die "Не задан порт: ни в конфиге, ни в параметре -p" unless $port;

GPBExim::App->new()
    ->start(server_port => $port, server_host => $host);