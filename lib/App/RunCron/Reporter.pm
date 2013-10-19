package App::RunCron::Reporter;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite (
    new => 1
);
sub run { die '`run` is abstract method' }

1;
