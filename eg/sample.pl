#!/usr/bin/env perl
use 5.014;
use warnings;
use utf8;
use FindBin::libs;
use autodie;

use App::RunCron;

my $runner = App::RunCron->new(
    timestamp => 1,
    command   => [qw/perl -E/, "die 'Hello'"],
    logfile   => 'tmp/log.log',
);

$runner->run;
