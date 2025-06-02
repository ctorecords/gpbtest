package GPBExim::Config;
use lib::abs '../../lib';
use uni::perl ':dumper';
use Config::Any;
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Carp;

my $CONFIG;

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

    return $CONFIG;
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
    my $start_dir = _get_start_dir();

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

sub _get_start_dir {
    return dirname(abs_path($0));
}

1;
