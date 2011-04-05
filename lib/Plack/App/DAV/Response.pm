package Plack::App::DAV::Response;
use parent 'Plack::Response';
use XML::LibXML;
use Plack::App::DAV::Property;
use Plack::App::DAV::Util;

sub dom {
    my $self = shift;
    $self->{dom} ||= do {
        $self->status(207);
        $self->content_type('application/xml; charset="utf-8"');
        my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
        my $root = $dom->createElement('multistatus');
        $root->setNamespace('DAV:', 'D');
        $dom->setDocumentElement($root);
        $dom;
    }
}

sub root { shift->dom->documentElement }

sub add_propstat {
    my ($self, $url, $item, $queries) = @_;
    my $res = dav_element($self->dom, 'response', undef, 0);
    dav_element($res, 'href', $url);
    my $property = Plack::App::DAV::Property->new($item);
    my $status;
    for my $query ($queries->nonBlankChildNodes) {
        my ($code, $response) = $property->query($query);
        push @{$status->{$code}}, $response;
    }
    for my $code (keys %$status) {
        my $propstat = $self->propstat($code);
        $propstat->addChild($_) for @{$status->{$code}};
        $res->addChild($propstat);
    }
    $self->root->addChild($res);
}

sub propstat {
    my $self = shift;
    my $code = shift || 200;
    my $propstat = dav_element($self->dom, 'propstat', undef, 0);
    dav_element(
        $propstat, 
        'status', 
        join(' ', 'HTTP/1.1', $code, HTTP::Status::status_message($code))
    );
    $propstat;
}

sub _body {
    my $self = shift;
    if ($self->{dom}) {
        [ $self->{dom}->toString(0) ];
    } else {
        $self->SUPER::_body;
    }
}

1;
