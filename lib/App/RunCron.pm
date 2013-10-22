package App::RunCron;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.03";

use Fcntl       qw(SEEK_SET);
use File::Temp  qw(tempfile);
use Time::HiRes qw/gettimeofday/;

use Class::Accessor::Lite (
    new => 1,
    ro  => [qw/timestamp command reporter error_reporter/],
    rw  => [qw/logfile logpos exit_code _finished/],
);

sub _logfh {
    my $self = shift;

    $self->{_logfh} ||= do {
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
    if (!$self->_finished) {
        $self->_run;
        exit $self->child_exit_code;
    }
    else {
        warn "already run. can't rerun.\n";
    }
}

sub _run {
    my $self = shift;
    die "no command specified" unless @{ $self->command };

    my $logfh = $self->_logfh;
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
    $self->_log($self->result_line. "\n");
    $self->_finished(1);

    if ($self->is_success) {
        $self->_send_report;
    }
    else {
        $self->_send_error_report;
    }
}

sub child_exit_code { shift->exit_code >> 8 }
sub is_success      { shift->exit_code == 0 }
sub result_line     {
    my $self = shift;
    $self->{result_line} ||= do {
        my $exit_code = $self->exit_code;
        if ($exit_code == -1) {
            "failed to execute command:$!";
        }
        elsif ($exit_code & 127) {
            "command died with signal:" . ($exit_code & 127);
        }
        else {
            "command exited with code:" . $self->child_exit_code;
        }
    };
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
            my @reporters = _retrieve_reporters($reporter);

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

sub _retrieve_reporters {
    my $reporter = shift;
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
    @reporters;
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
    my $logfh = $self->_logfh;
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

=for stopwords cron crontab logfile eg

=encoding utf-8

=head1 NAME

App::RunCron - making wrapper script for crontab

=head1 SYNOPSIS

    use App::RunCron;
    my $runner = App::RunCron->new(
        timestamp => 1,
        command   => [@ARGV],
        logfile   => 'tmp/log%Y-%m-%d.log',
        reporter  => 'Stdout',
        error_reporter => [
            'Stdout',
            'File', {
                file => 'tmp/error%Y-%m-%d.log'
            },
        ],
    );
    $runner->run;

=head1 DESCRIPTION

App::RunCron is a software for making wrapper script for running cron tasks.

App::RunCron can separate reporting way if the command execution success or failed
(i.e. fails to start, or returns a non-zero exit code, or killed by a signal).
It is handled by `reporter` and `error_reporter` option.

By default, `reporter` is 'None' and `error_reporter` is 'Stdout'.
It prints the outputs the command if and only if the command execution failed.
In other words, this behaviour causes L<cron(8)> to send mail when and only when an error occurs.

Default behaviour is same like L<cronlog|https://github.com/kazuho/kaztools/blob/master/cronlog>.

=head1 OPTIONS

=head2 timestamp

Add timestamp or not. (Default: undef)

=head2 command

command to be executed. (Required)

=head2 logfile

If logfile is specified, stdout and stderr of the command will be logged to the file so that it could be used for later inspection. 
If not specified, the outputs will not be logged.
The logfile can be a C<strftime> format. eg. '%Y-%m-%d.log'. (NOTICE: '%' must be escaped in crontab.)

=head2 reporter|error_reporter

The reporter and error_reporter can be like following.

=over

=item C<< $module_name >>

=item C<< [$module_name[, \%opt], ...] >>

=item C<< $coderef >>

=back

I<$module_name> package name of the plugin. You can write it as two form like L<DBIx::Class>:

    reporter => 'Stdout',    # => loads App::RunCron::Reporter::Stdout

If you want to load a plugin in your own name space, use the '+' character before a package name, like following:

    reporter => '+MyApp::Reporter::Foo', # => loads MyApp::Reporter::Foo

=head2 METHODS AND ACCESORS

=head3 C<< $self->run >>

Running the job.

=head3 C<< my $str = $self->result_line >>

One line result string of the command.

=head3 C<< my $str = $self->report >>

Retrieve the output of the command.

=head3 C<< my $bool = $self->is_success >>

command is success or not.

=head3 C<< my $int = $self->exit_code >>

same as C<$?>

=head3 C<< my $int = $self->child_exit_code >>

exit code of child process.

=head1 SEE ALSO

L<runcron>, L<cronlog|https://github.com/kazuho/kaztools/blob/master/cronlog>

=head1 LICENSE

Copyright (C) Songmu.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Songmu E<lt>y.songmu@gmail.comE<gt>

=cut
