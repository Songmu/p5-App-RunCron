[![Build Status](https://travis-ci.org/Songmu/p5-App-RunCron.png?branch=master)](https://travis-ci.org/Songmu/p5-App-RunCron) [![Coverage Status](https://coveralls.io/repos/Songmu/p5-App-RunCron/badge.png?branch=master)](https://coveralls.io/r/Songmu/p5-App-RunCron?branch=master)
# NAME

App::RunCron - making wrapper script for crontab

# SYNOPSIS

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

# DESCRIPTION

App::RunCron is a software for making wrapper script for running cron tasks.

App::RunCron can separate reporting way if the command execution success or failed
(i.e. fails to start, or returns a non-zero exit code, or killed by a signal).
It is handled by \`reporter\` and \`error\_reporter\` option.

By default, \`reporter\` is 'None' and \`error\_reporter\` is 'Stdout'.
It prints the outputs the command if and only if the command execution failed.
In other words, this behaviour causes [cron(8)](http://man.he.net/man8/cron) to send mail when and only when an error occurs.

Default behaviour is same like [cronlog](https://github.com/kazuho/kaztools/blob/master/cronlog).

# OPTIONS

## timestamp

Add timestamp or not. (Default: undef)

## command

command to be executed. (Required)

## logfile

If logfile is specified, stdout and stderr of the command will be logged to the file so that it could be used for later inspection. 
If not specified, the outputs will not be logged.
The logfile can be a `strftime` format. eg. '%Y-%m-%d.log'. (NOTICE: '%' must be escaped in crontab.)

## reporter|error\_reporter

The reporter and error\_reporter can be like following.

- `$module_name`
- `[$module_name[, \%opt], ...]`
- `$coderef`

_$module\_name_ package name of the plugin. You can write it as two form like [DBIx::Class](http://search.cpan.org/perldoc?DBIx::Class):

    reporter => 'Stdout',    # => loads App::RunCron::Reporter::Stdout

If you want to load a plugin in your own name space, use the '+' character before a package name, like following:

    reporter => '+MyApp::Reporter::Foo', # => loads MyApp::Reporter::Foo

### SEE ALSO

[runcron](http://search.cpan.org/perldoc?runcron), [cronlog](https://github.com/kazuho/kaztools/blob/master/cronlog)

# LICENSE

Copyright (C) Songmu.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Songmu <y.songmu@gmail.com>
