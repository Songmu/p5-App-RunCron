package App::RunCron::CLI;
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Pod::Usage;
use Time::Piece;

use App::RunCron;

sub new {
    my ($class, @argv) = @_;

    local @ARGV = @argv;
    my $p = Getopt::Long::Parser->new(
        config => [qw/pass_through posix_default no_ignore_case bundling auto_help/],
    );
    $p->getoptions(\my %opt, qw/
        logfile=s
        timestamp
        reporter=s
        error_reporter=s
        config|c=s
    /) or pod2usage(1);

    $opt{command} = [@ARGV];
    $class->new_with_options(%opt);
}

sub new_with_options {
    my ($class, %opt) = @_;

    if ($opt{logfile}) {
        my $now = localtime;
        $opt{logfile} = $now->strftime($opt{logfile});
    }

    bless {
        runner => App::RunCron->new(%opt),
    }, $class;
}

sub run {
    shift->{runner}->run
}

1;
