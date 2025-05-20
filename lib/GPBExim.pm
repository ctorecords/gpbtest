package GPBExim;

use strict;
use warnings; 
use lib::abs '../lib';

sub db_connect {
    my $db_type = shift;

    # фабрика для модели
    $db_type =~ /^[A-Za-z0-9_\:]+$/ or die "Недопустимое имя модуля: $db_type";
    my $db_module = "GPBExim::Model::$db_type";
    (my $file = "$db_module.pm") =~ s{::}{/}g;
    eval {
        require $file;
        $db_module->import();
        1;
    } or die "Ошибка загрузки модуля $db_module: $@";

    return $db_module->new();
}

sub setup_schema {
    my $dbh = shift;
    my $sql = do { local(@ARGV, $/) = 'schema/SQLite3.sql'; <> };
    $dbh->do($_) for split /;/, $sql;
}

1;



