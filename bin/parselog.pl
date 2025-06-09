#!/usr/bin/env perl
use lib::abs '../lib';
use uni::perl ':dumper';
use GPBExim;
use GPBExim::Parser;
use GPBExim::Config;
use GPBExim::Log;
use Getopt::Long;
use Cwd qw(abs_path);

# Опция --no-setup нужна для случаев, когда
# парсим последовательно несколько лог-файлов для накопления информации о них
my $no_setup;
GetOptions(
    'no-setup' => \$no_setup,
) or die "Неверные параметры запуска. Использование: $0 [--no-setup] <logfile_path>\n";

my $logfile = shift @ARGV or die "Не передан путь к лог-файлу. Использование: $0 [--no-setup] <logfile_path>\n";

$logfile = abs_path($logfile) or die "Не удалось определить абсолютный путь к '$logfile'\n";
-f $logfile or die "Файл '$logfile' не существует или не является обычным файлом\n";

my $cfg = GPBExim::Config->get();
log(info => "User asks to parse file %s", $logfile);
my $model;
my $parser;

log(debug => "Get model %s", $cfg->{db}{model_type});
$model = GPBExim::get_model($cfg->{db}{model_type});
log(debug => "Setup schema %s", $model->{schema_path});
$model->setup_schema() unless $no_setup;
$parser = GPBExim::Parser->new();

$parser->parse_logfile($logfile => $model);
log(info => "Indexed emails: %d", $model->emails_indexed_counter);
