package GPBExim::Config;
use lib::abs '../../lib';
use uni::perl ':dumper';
use Config::Any;
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Carp;
use Log::Log4perl;
use Log::Any;
use Log::Any::Adapter;


my $CONFIG;
my $LOGGER;

sub get {
    return $CONFIG if $CONFIG;

    my ($config_path, $config_dir) = _find_config_file();

    my $cfg_loader  = Config::Any->load_files({ files => [$config_path], use_ext => 1 });

    foreach my $entry (@$cfg_loader) {
        ($CONFIG) = values %$entry;
        last if $CONFIG;
    }

    croak "Не удалось загрузить конфигурацию из $config_path" unless $CONFIG;

    _resolve_paths($CONFIG, $config_dir);

    if (my $log_cfg = $CONFIG->{log}) {
        my $log_section;

        # Выбор конфигурации логгера: pattern или json
        if ($log_cfg->{use} && $log_cfg->{use} eq 'json') {
            $log_section = $log_cfg->{log4perl_json};
        } else {
            $log_section = $log_cfg->{log4perl};
        }

        if ($log_section && ref $log_section eq 'HASH') {
            my $root = 'log4perl.rootLogger';
            my $log_conf_str = join "\n", "$root=$log_section->{$root}",
                map { "$_=$log_section->{$_}" }
                sort grep { $_ ne $root } keys %$log_section;

            Log::Log4perl::init(\$log_conf_str);
            Log::Any::Adapter->set('Log4perl');
            $LOGGER = Log::Any->get_logger();
        } else {
            warn "Логгер не настроен: отсутствует секция log4perl или log4perl_json в конфиге"
        }
        delete $CONFIG->{log};
    }

    return $CONFIG;
}

sub logger {
    return $LOGGER //= Log::Any->get_logger();
}

sub _resolve_paths {
    my ($hash, $base_dir) = @_;

    foreach my $key (keys %$hash) {
        my $value = $hash->{$key};

        if (ref $value eq 'HASH') {
            _resolve_paths($value, $base_dir);
        }
        elsif ($key =~ /path$/i && !ref $value) {
            $hash->{$key} = File::Spec->catfile($base_dir, $value);
        }
    }
}

sub _find_config_file {
    my @filenames = qw(config.yaml config.yml config.json config.pl);
    my $start_dir = dirname(abs_path($0));

    while ($start_dir) {
        foreach my $file (@filenames) {
            my $candidate = File::Spec->catfile($start_dir, $file);
            return ($candidate, $start_dir) if -e $candidate;
        }

        my $parent = dirname($start_dir);
        last if $parent eq $start_dir;
        $start_dir = $parent;
    }

    croak "Конфигурационный файл не найден (искали вверх от точки запуска среди: @filenames)";
}

1;
