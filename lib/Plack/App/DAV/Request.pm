package Plack::App::DAV::Request;
use parent 'Plack::Request';
use Plack::App::DAV::Response;
use XML::LibXML;
use Plack::App::DAV::Util;

sub dom {
    my $self = shift;
    $self->{dom} ||= XML::LibXML->load_xml(string => $self->content);
}

sub propfind_prop {
    my $self = shift;
    find('/D:propfind/D:prop', $self->dom)->shift->cloneNode(1);
}

sub new_response {
    my $self = shift;
    Plack::App::DAV::Response->new(@_);
}

1;
