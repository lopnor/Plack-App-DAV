package Plack::App::DAV;
use strict;
use warnings;
use utf8;
use parent 'Plack::App::Directory';
use Try::Tiny;
use Plack::App::DAV::Request;
use URI::Escape;
use File::Spec::Unix;
use File::Find::Rule;
use File::Basename;
use File::stat ();
use File::Copy ();

our $VERSION = '0.01';

sub allow_path_info {1}

my $allow_path_info_methods;
sub allow_path_info_method { 
    my ($self, $method) = @_;
    $allow_path_info_methods ||= +{ map {$_ => 1} qw(put mkcol)};
    return $allow_path_info_methods->{$method};
}

my $supported;
sub supported_method {
    my ($self, $method) = @_;
    $supported ||= +{ map {$_ => 1} qw(get head options propfind mkcol put delete copy move) };
    return $supported->{$method};
}
    

sub locate_file {
    my($self, $thing) = @_;

    my $path = ref $thing eq 'HASH' ? $thing->{PATH_INFO} || '' : $thing;
    if ($path =~ m!\.\.[/\\]!) {
        return $self->return_403;
    }

    my $docroot = $self->root || ".";
    my @path = split '/', $path;
    @path = ('') unless @path;

    my($file, @path_info);
    while (@path) {
        my $try = File::Spec::Unix->catfile($docroot, @path);
        if ($self->should_handle($try)) {
            $file = $try;
            last;
        } elsif (!$self->allow_path_info) {
            last;
        }
        unshift @path_info, pop @path;
    }

    if (!$file) {
        return $self->return_404;
    }

    if (!-r $file) {
        return $self->return_403;
    }

    return $file, join("/", @path_info);
}

sub serve_path {
    my ($self, $env, $file) = @_;
    my $method = lc $env->{REQUEST_METHOD};
    unless ($self->supported_method($method)) {
        return [501, ['Content-Type', 'text/plain'], ['Not Implemented']];
    }
    if ($env->{PATH_INFO} && !$self->allow_path_info_method($method)) {
        return $self->return_404;
    }
    try {
        $self->$method($env, $file);
    } catch {
        warn $_;
        ref($_) eq 'Plack::Response' ?
            $_->finalize : [400, ['Content-Type', 'text/plain'], ['Bad Request']];
    }
}

sub get { shift->SUPER::serve_path(@_) }

sub head { 
    my $res = shift->get(@_);
    $res->[2] = [];
    $res;
}

sub options {
    [   
        200, 
        [
            'DAV'           => '1,2,<http://apache.org/dav/propset/fs/1>',
            'MS-Author-Via' => 'DAV',
            'Allow'         => join(',', map {uc} keys %$supported),
        ],
        []
    ]
}

sub propfind {
    my ($self, $env, $dir) = @_;

    my $req = Plack::App::DAV::Request->new($env);

    my @items = (''); # $dir itself
    if (-d $dir && $req->header('Depth') == 1) {
        my $dh = DirHandle->new($dir);
        while (defined(my $ent = $dh->read)) {
            $ent eq '.' || $ent eq '..' and next;
            push @items, $ent;
        }
        $dir =~ s{/$}{};
    }

    my $props = $req->propfind_prop;
    my $res = $req->new_response;
    for my $basename (@items) {
        my $file = $basename ? "$dir/$basename" : $dir;
        my $url = $req->script_name . $req->path_info;
        $url .= '/' unless $url =~ m{/$};
        $url .= $basename;
        $url = join('/', map {uri_escape($_)} split( m{/}, $url )) || '/';
        $res->add_propstat($url, $file, $props);
    }
    $res->finalize;
}

sub mkcol {
    my ($self, $env, $dir) = @_;

    my $req = Plack::App::DAV::Request->new($env);
    my $path = $req->path_info;

    my $res = $req->new_response(201);
    {
        $path                   or  $res->code(405) and last;
        $req->content           and $res->code(415) and last;
        $req->path_info =~ m{/} and $res->code(409) and last;
        -d $dir                 or  $res->code(409) and last;
        my $target = File::Spec::Unix->catfile($dir, $path);
        mkdir $target           or  $res->code(409) and last;
        -d $target              or  $res->code(409) and last;
    }

    $res->finalize;
}

sub put {
    my ($self, $env, $dir) = @_;

    my $req = Plack::App::DAV::Request->new($env);

    my $res = $req->new_response(201);
    {
        $req->path_info =~ m{/}     and $res->code(409) and last;
        -d $dir                     or  $res->code(409) and last;
        my $target = File::Spec::Unix->catfile($dir, $req->path_info);
        -d $target                  and $res->code(405) and last;
        try {
            open my $fh, '>', $target or die $@;
            binmode($fh);
            print $fh $req->content;
            close $fh;
        } catch {
            $res->code(403);
        };
    }

    $res->finalize;
}

sub delete {
    my ($self, $env, $dir) = @_;

    my $req = Plack::App::DAV::Request->new($env);

    my $res = $req->new_response(204);
    {
        $req->uri->fragment and $res->code(404) and last;
        
        try {
            for my $target (reverse File::Find::Rule->in($dir)) {
                if (-d $target) {
                    rmdir $target;
                } else {
                    unlink $target;
                }
            }
        } catch {
            $res->code(423);
        };
    }

    $res->finalize;
}

sub copy {
    my ($self, $env, $file) = @_;
    my $req = Plack::App::DAV::Request->new($env);
    my ($dir, $pathinfo) = $self->locate_file(
        URI->new($req->header('Destination'))->path
    );
    my $depth = $req->header('Depth');
    my $overwrite = $req->header('Overwrite');

    my $res = $req->new_response(201);
    {
        $pathinfo =~ m{/} and $res->code(409) and last;
        my $dest = $pathinfo ? "$dir/$pathinfo" : $dir;
        my $stat_file = File::stat::stat($file);
        if (-f $stat_file) {
            $res->code($self->copy_file($file, $dest, $overwrite));
        } elsif (-d $stat_file) {
            if (my $dest_stat = File::stat::stat($dest)) {
                -f $dest_stat and $res->code(412) and last;
                -d $dest_stat && $overwrite eq 'F' and $res->code(412) and last;
            } else {
                mkdir $dest;
            }
            for my $target ( File::Find::Rule->in($file) ) {
                (my $subdir = $target) =~ s/^$file//;
                my $subdest = "$dest/$subdir";
                $subdest =~ s{/+}{/}g;
                warn $subdest;
                if (-d $target) {
                    mkdir $subdest;
                } else {
                    $self->copy_file($target, $subdest, $overwrite);
                }
            }
        }
    }
    $res->finalize;
}

sub copy_file {
    my ($self, $from, $to, $overwrite) = @_;
    my $code = 201;
    if (-d $to) {
        $to = $to . "/" unless $to =~ m{/$};
        $to .= basename($from);
        $code = 204;
    }
    if (-f $to) {
        $overwrite eq 'F' and return 412;
        $code = 204;
    }
    File::Copy::copy($from, $to) or $code = 403;
    return $code;
}

sub move {
    my ($self, $env, $dir) = @_;
    my $res = $self->copy($env, $dir);
    if ($res->[0] == 201 || $res->[0] == 204) {
        $res = $self->delete($env, $dir);
    }
    return $res;
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
