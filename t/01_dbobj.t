use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::App::DAV;
use HTTP::Request::Common;

my $lockdb = 't/lockdb.sqlite3';

my $configs = [
    {},
    { root => '.' },
    {
        root => '.',
        dbobj => 'Simple',
    },
    {
        dbobj => 'DB',
    },
    {
        dbobj => [ 'DB', 'dbi:SQLite:' ],
    },
    {
        dbobj => [ 'DB', "dbi:SQLite:$lockdb" ],
    },
];

for my $config (@$configs) {
    test_psgi 
        app => Plack::App::DAV->new(
            %$config
        )->to_app, 
        client => sub {
            my $cb = shift;
            ok my $res = $cb->(GET '/');
            ok $res->is_success;
        };
}

unlink $lockdb;

done_testing;
