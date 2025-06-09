package GPBExim::Log::JSONLayout;

use lib::abs '../../../lib';
use uni::perl;
use base qw(Log::Log4perl::Layout);
use JSON::XS;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub render {
    my ($self, $message, $category, $priority, $caller_level) = @_;
    my ($package, $filename, $line, $subroutine) = caller($caller_level+4);
    return encode_json({
        time     => scalar localtime,
        level    => $priority,
        message  => $message,
        caller => "$filename:$line",
    }) . "\n";
}

1;
