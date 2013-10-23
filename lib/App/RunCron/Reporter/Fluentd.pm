package App::RunCron::Reporter::Fluentd;
use strict;
use warnings;
use utf8;

use Fluent::Logger;

use parent 'App::RunCron::Reporter';

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;

    $args{tag_prefix} ||= 'runcron';

    bless \%args, $class;
}

sub run {
    my ($self, $runcron) = @_;

    my $logger = Fluent::Logger->new(%$self);
    $logger->post('' => {
        report          => $runcron->report,
        command         => join(' ', @{ $runcron->command }),
        result_line     => $runcron->result_line,
        is_success      => $runcron->is_success,
        child_exit_code => $runcron->child_exit_code,
        exit_code       => $runcron->exit_code,
        child_signal    => $runcron->child_signal,
    });
}

1;
