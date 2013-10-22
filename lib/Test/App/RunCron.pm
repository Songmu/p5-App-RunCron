package Test::App::RunCron;
use strict;
use warnings;
use utf8;

use App::RunCron;
use Test::More;
use YAML::Tiny;

use parent 'Exporter';

our @EXPORT = qw/runcron_yml_ok mock_runcron/;

sub runcron_yml_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $yml = shift || 'runcron.yml';
    eval {
        my $conf = YAML::Tiny::LoadFile($yml);
        my $obj = App::RunCron->new($conf);

        my @reporters;
        if ($conf->{reporter}) {
            @reporters = App::RunCron::_retrieve_reporters($conf->{reporter});
        }

        if ($conf->{error_reporter}) {
            @reporters = App::RunCron::_retrieve_reporters($conf->{error_reporter});
        }

        for my $r (@reporters) {
            my ($class, $arg) = @$r;
            App::RunCron::_load_reporter($class)->new($arg || ());
        }
    };

    if ($@) {
        fail $@;
    }
    else {
        ok "$yml ok";
    }
}

sub mock_runcron {
    my %args = @_ == 1 ? $_[0] : @_;
}

1;
