package GPBExim;

use lib::abs '../lib';
use uni::perl;

sub get_model {
    my $db_type = shift;
    my %args = @_;

    # фабрика для модели
    $db_type =~ /^[A-Za-z0-9_\:]+$/ or die "Недопустимое имя модуля: $db_type";
    my $db_module = "GPBExim::Model::$db_type";
    (my $file = "$db_module.pm") =~ s{::}{/}g;
    eval {
        require $file;
        $db_module->import();
        1;
    } or die "Ошибка загрузки модуля $db_module: $@";

    return $db_module->new(%args);
}

1;



