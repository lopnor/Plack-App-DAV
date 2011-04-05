package Plack::App::DAV::Property;
use strict;
use warnings;
use File::stat ();
use HTTP::Date;
use Plack::Util::Accessor qw(file stat);
use Plack::App::DAV::Util;

sub new {
    my ($class, $file) = @_;
    my $stat = File::stat::stat($file);
    bless {
        file => $file,
        stat => $stat,
    }, $class;

}

sub query {
    my ($self, $query) = @_;
    my $node = $query->cloneNode(1);
    my $method = $self->method($node);
    if ($method) {
        $self->$method($node);
        return '200', $node;
    } else {
        return '404', $node;
    }
}

sub getcontentlength {
    my ($self, $node) = @_;
    $node->appendText($self->stat->size);
}

sub resourcetype {
    my ($self, $node) = @_;
    dav_element($node, 'collection') if -d $self->stat;
}

sub getlastmodified {
    my ($self, $node) = @_;
    $node->appendText(time2str($self->stat->mtime));
}

my $methods = {
    'DAV:' => +{ map {$_ => $_} qw(getcontentlength resourcetype getlastmodified) }
};

sub method {
    my ($self, $query) = @_;
    $methods->{$query->namespaceURI}->{$query->localname};
}

1;
