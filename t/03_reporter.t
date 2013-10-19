use strict;
use warnings;
use utf8;
use Test::More;

for my $reporter (qw/Stdout File None/) {
    my $class = "App::RunCron::Reporter::$reporter";
    use_ok $class;
    ok $class->can('new');
    ok $class->can('run');
}

done_testing;
