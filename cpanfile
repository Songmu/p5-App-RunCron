requires 'Class::Accessor::Lite';
requires 'Time::Piece';
requires 'parent';
requires 'YAML::Tiny';
requires 'perl', '5.008001';

on configure => sub {
    requires 'CPAN::Meta';
    requires 'CPAN::Meta::Prereqs';
    requires 'Module::Build';
};

on test => sub {
    requires 'Capture::Tiny';
    requires 'File::pushd';
    requires 'Test::Exit';
    requires 'Test::Tester';
    requires 'Test::Mock::Guard';
    requires 'Test::More', "0.98";
};
