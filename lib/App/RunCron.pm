package App::RunCron;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Fcntl       qw(SEEK_SET);
use File::Temp  qw(tempfile);
use Time::HiRes qw/gettimeofday/;

use Class::Accessor::Lite (
    new => 1,
    ro  => [qw/timestamp command reporter error_reporter/],
    rw  => [qw/logfile logpos exit_code/],
);

sub logfh {
    my $self = shift;

    $self->{logfh} ||= do {
        my $logfh;
        my $logfile = $self->{logfile};
        if ($logfile) {
            open $logfh, '>>', $logfile or die "failed to open file:$logfile:$!";
        } else {
            ($logfh, $logfile) = tempfile(UNLINK => 1);
            $self->logfile($logfile);
        }
        autoflush $logfh 1;
        print $logfh '-'x78, "\n";
        $self->logpos(tell $logfh);
        die "failed to obtain position of logfile:$!" if $self->logpos == -1;
        seek $logfh, $self->logpos, SEEK_SET or die "cannot seek within logfile:$!";
        $logfh;
    };
}

sub run {
    my $self = shift;
    $self->_run;
    exit($self->exit_code >> 8);
}

sub _run {
    my $self = shift;
    die "no command specified" unless @{ $self->command };

    my $logfh = $self->logfh;
    pipe my $logrh, my $logwh or die "failed to create pipe:$!";

    # exec
    $self->_log(
        do { my $h = `hostname 2> /dev/null`; chomp $h; $h }
        . ' starting: ' . join(' ', @{ $self->command }) . "\n",
    );
    $self->exit_code(-1);
    unless (my $pid = fork) {
        if (defined $pid) {
            # child process
            close $logrh;
            close $logfh;
            open STDERR, '>&', $logwh or die "failed to redirect STDERR to logfile";
            open STDOUT, '>&', $logwh or die "failed to redirect STDOUT to logfile";
            close $logwh;
            exec @{ $self->command };
            die "exec(2) failed:$!:@{ $self->command }";
        }
        else {
            close $logrh;
            close $logwh;
            print $logfh, "fork(2) failed:$!\n" unless defined $pid;
        }
    }
    else {
        close $logwh;
        $self->_log($_) while <$logrh>;
        close $logrh;
        while (wait == -1) {}
        $self->exit_code($?);
    }

    # end
    my $exit_code = $self->exit_code;
    if ($exit_code == -1) {
        $self->_log("failed to execute command:$!\n");
    }
    elsif ($exit_code & 127) {
        $self->_log("command died with signal:" . ($exit_code & 127) . "\n");
    }
    else {
        $self->_log("command exited with code:" . ($exit_code >> 8) ."\n");
    }

    if ($exit_code != 0) {
        $self->_send_error_report;
    }
    else {
        $self->_send_report;
    }
}

sub report {
    my $self = shift;

    $self->{report} ||= do {
        open my $fh, '<', $self->logfile or die "failed to open @{[$self->logfile]}:$!";
        seek $fh, $self->logpos, SEEK_SET      or die "failed to seek to the appropriate position in logfile:$!";
        my $report = '';
        $report .= $_ while <$fh>;
        $report;
    }
}

sub _send_report {
    my $self = shift;

    my $reporter = $self->reporter || 'None';
    $self->_do_send_report($reporter);
}

sub _send_error_report {
    my $self = shift;

    my $reporter = $self->error_reporter || 'Stdout';
    $self->_do_send_report($reporter);
}

sub _do_send_report {
    my ($self, $reporter) = @_;

    eval {
        if (ref($reporter) && ref($reporter) eq 'CODE') {
            $reporter->($self);
        }
        else {
            my @reporters;
            if (ref $reporter && ref($reporter) eq 'ARRAY') {
                my @stuffs = @$reporter;

                while (@stuffs) {
                    my $reporter_class = shift @stuffs;
                    my $arg;
                    if ($stuffs[0] && ref $stuffs[0]) {
                        $arg = shift @stuffs;
                    }
                    push @reporters, [$reporter_class, $arg || ()];
                }
            }
            else {
                push @reporters, [$reporter];
            }

            for my $r (@reporters) {
                my ($class, $arg) = @$r;
                _load_reporter($class)->new($arg || ())->run($self);
            }
        }
    };
    if (my $err = $@) {
        warn $self->report;
        warn $err;
    }
}

sub _load_reporter {
    my $class = shift;
    my $prefix = 'App::RunCron::Reporter';
    unless ($class =~ s/^\+// || $class =~ /^$prefix/) {
        $class = "$prefix\::$class";
    }

    my $file = $class;
    $file =~ s!::!/!g;
    require "$file.pm"; ## no citic

    $class;
}

sub _log {
    my ($self, $line) = @_;
    my $logfh = $self->logfh;
    print $logfh (
        ($self->timestamp ? _timestamp() : ''),
        $line,
    );
}

sub _timestamp {
    my @tm = gettimeofday;
    my @dt = localtime $tm[0];
    sprintf('[%04d-%02d-%02d %02d:%02d:%02d.%06.0f] ',
        $dt[5] + 1900,
        $dt[4] + 1,
        $dt[3],
        $dt[2],
        $dt[1],
        $dt[0],
        $tm[1],
    );
}

__END__

=encoding utf-8

=head1 NAME

App::RunCron - It's new $module

=head1 SYNOPSIS

    use App::RunCron;

=head1 DESCRIPTION

App::RunCron is ...

=head1 LICENSE

Copyright (C) Songmu.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Songmu E<lt>y.songmu@gmail.comE<gt>

=cut

