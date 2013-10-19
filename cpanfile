requires 'Class::Accessor::Lite';
requires 'Time::Piece';
requires 'parent';
requires 'perl', '5.008001';

on configure => sub {
    requires 'CPAN::Meta';
    requires 'CPAN::Meta::Prereqs';
    requires 'Module::Build';
};

on test => sub {
    requires 'Capture::Tiny';
    requires 'Test::More';
};
