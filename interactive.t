use strict;
use lib 't/lib';
use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();
ok(1, 'interactive mode started');
sleep(10000000);
ok(1, 'interactive mode ended');