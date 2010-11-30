use inc::Module::Install;
name 'Plack-App-DAV';
all_from 'lib/Plack/App/DAV.pm';

requires 'Plack' => '0.9021';
requires 'Net::DAV::Server';
requires 'Filesys::Virtual::Plain';
requires 'HTTP::Request';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
