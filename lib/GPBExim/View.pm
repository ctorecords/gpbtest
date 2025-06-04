package GPBExim::View;

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Status;
use uni::perl ':dumper';
use Template;
use Encode;
use HTTP::Status qw(:constants);
use JSON::XS;

use lib::abs '../../lib';
use GPBExim;
use GPBExim::Config;

sub new {
    my $pkg  = shift;
    my %args = (
        @_,
    );

    my $self = bless {  %args }, $pkg;
    $self->{cfg} = GPBExim::Config->get();

    return $self;
}

sub render {
    my $self = shift;
    my $data = shift;
    my %args = @_;

    # если пришёл готовый HTTP::Response, просто его возвращаем
    if ($data->{render} eq 'HTTP::Response') {
        return $data->{data};
    }

    # рендер через Template::Toolkit
    if ($data->{render} eq 'TT') {
        my $tt = Template->new(TRIM => 1, ABSOLUTE => 1);
        my $body = '';
        $tt->process( $data->{template}, $data, \$body )
            or die $tt->error();

        my $resp = HTTP::Response->new(RC_OK, undef, undef, $body);
        $resp->header('Content-Type' => 'text/html; charset=utf-8');
        return $resp;
    }

    # рендер JSON
    if ($data->{render} eq 'JSON') {
        my $body = encode_json($data);

        my $resp = HTTP::Response->new(RC_OK, undef, undef, encode('UTF-8', $body));
        $resp->header('Content-Type' => 'application/json; charset=utf-8');
        return $resp;
    }

    # возвращаем просто данные, если дошли до этой строки
    return { data => $data->{data} };
}


1;