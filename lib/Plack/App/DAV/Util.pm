package Plack::App::DAV::Util;
use strict;
use warnings;
use XML::LibXML;

sub import {
    my ($class, %args) = @_;
    my $caller = caller;
    {
        no strict 'refs';
        for (qw(dav_element find)) {
            *{"$caller\::$_"} = \&{$_};
        }
    }
}

sub dav_element {
    my ($elem, $localname, $text, $append) = @_;
    $append ||= 1;
    my $child = $elem->ownerDocument->createElement($localname);
    $child->setNamespace('DAV:', 'D');
    $child->appendText($text) if defined $text;
    $elem->addChild($child) if $append;
    return $child;
}

sub find {
    my ($xpath, $node) = @_;
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs('D', 'DAV:');
    $xpc->find($xpath, $node);
}

1;
