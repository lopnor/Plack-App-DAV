package Plack::App::DAV;
use strict;
use warnings;
use parent 'Plack::Component';
use Plack::Request;
use HTTP::Request;
use Net::DAV::Server;
use Filesys::Virtual::Plain;

use Plack::Util::Accessor qw(root);

our $VERSION = '0.01';

sub prepare_app {
    my $self = shift;
    $self->{dav} = Net::DAV::Server->new(
        -filesys => Filesys::Virtual::Plain->new({root_path => $self->root || '.'})
    );
}

sub call {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);
    my $res = $self->{dav}->run(
        HTTP::Request->new(
            $req->method,
            $req->uri,
            $req->headers,
            $req->content
        )
    );
    return $req->new_response(
        $res->code,
        $res->headers,
        $res->content,
    )->finalize;
}

1;
__END__

=head1 NAME

Plack::App::DAV - simple DAV server for Plack

=head1 SYNOPSIS

  plackup -MPlack::App::DAV -e 'Plack::App::DAV->new->to_app'

=head1 DESCRIPTION

Plack::App::DAV is simple DAV server for Plack.

=head1 AUTHOR

Nobuo Danjou E<lt>nobuo.danjou@gmail.comE<gt>

=head1 SEE ALSO

L<Net::DAV::Server>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
