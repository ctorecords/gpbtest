package GPBExim::Log;

use strict;
use warnings;
use uni::perl ':dumper';
use lib::abs '../../lib';
use GPBExim::Config;
use Encode;

use Exporter 'import';
our @EXPORT = qw(log);

my $logger = GPBExim::Config::logger();

sub log {
    my $level = shift;
    my @args  = @_;

    $logger //= GPBExim::Config::logger();
    my $msg='';
    if (!ref($args[0])) {
        $msg = shift @args;
    };
    if (@args) {
        if ($msg =~ /%[sd]/) {
            $msg = sprintf($msg, @args);
        } elsif (@args == 1 && ref $args[0]) {
            $msg .= ' ' . _format($args[0]);
        } else {
            $msg .= ' ' . join(' ', map { _format($_) } @args);
        }
    }

    $logger->$level($msg);
}

sub _format {
    my $val = shift;
    my $str = eval { encode_json($val) } || dumper($val);
    $str =~ s{[\r\n]}{}gxis;
    return $str;
}

1;
