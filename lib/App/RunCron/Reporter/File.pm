package App::RunCron::Reporter::File;
use strict;
use warnings;
use utf8;

use Time::Piece;
use parent 'App::RunCron::Reporter';
use Class::Accessor::Lite (
    new => 1,
    ro  => [qw/file/],
);

sub run {
    my ($self, $runner) = @_;

    my $file = $self->file or die 'file is required option';
    my $now = localtime;
    $file = $now->strftime($file);

    open my $fh, '>>', $file or die $!;
    print $fh $runner->report;
    close $fh;
}

1;
