package Plack::App::DAV;
use strict;
use warnings;
use parent 'Plack::Component';
use Plack::Request;
use HTTP::Request;
use Net::DAV::Server;
use Filesys::Virtual::Plain;

use Plack::Util::Accessor qw(root dbobj);

our $VERSION = '0.01';

sub prepare_app {
    my $self = shift;

    my ($classname, $args) = ref($self->dbobj) ?  
        @{$self->dbobj} : 
        $self->dbobj || 'Simple';
    my $class = Plack::Util::load_class($classname, 'Net::DAV::LockManager')
        or die 'could not load LockManager class';

    $self->{dav} = Net::DAV::Server->new(
        -filesys => Filesys::Virtual::Plain->new({root_path => $self->root || '.'}),
        -dbobj => $class->new($args),
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

=head1 CONFIGURATION

=over 4

=item root

Document root directory. Defaults to the current directory.

=item dbobj

class specification and instanciate arguments for Net::DAV::LockManager.
Defaults to 'Simple', makes Net::DAV::LockManager::Simple instance.

  my $app = Plack::App::DAV->new;

is identical to the below.

  my $app = Plack::App::DAV->new(dbobj => 'Simple');

To make LockManager with sqlite DB, write

  my $app = Plack::App::DAV->new(
      dbobj => [DB => 'dbi:sqlite:lockdb.sqlite3']
  );

=back

=head1 AUTHOR

Nobuo Danjou E<lt>nobuo.danjou@gmail.comE<gt>

=head1 SEE ALSO

L<Net::DAV::Server>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
