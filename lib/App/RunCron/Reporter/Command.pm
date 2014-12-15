package App::RunCron::Reporter::Command;
use strict;
use warnings;
use JSON::PP;

sub new {
    my ($class, $command) = @_;
    bless \$command, $class;
}

sub run {
    my ($self, $runner) = shift;

    open my $pipe, '|-', $$self or die $!;
    print $pipe encode_json($self->report_data);
    close $pipe;
}

1;
