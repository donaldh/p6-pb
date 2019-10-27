use Test;
use PB::Grammar;

# to automate the testing of this grammar
sub g_ok (Str $testme, Str $desc?) { ok PB::Grammar.parse($testme), $desc; }

# download the unit test files from the offical google repo and test our grammar against them
if run('which', 'git') == 0 {
    say 'git is installed... checking for protobuf repo';

    my $absdir = $?FILE.path.dirname;
    my $pbdir = $*SPEC.join: '', $absdir, 'data/protobuf-read-only';

    if ! $pbdir.path.d {
        run 'git', 'clone', 'https://github.com/google/protobuf.git', $pbdir;
    } else {
        temp $*CWD = $pbdir;
        run 'git', 'pull';
    }

    my $srcdir = $*SPEC.join: '', $pbdir, 'src/google/protobuf';
    my @files = dir $srcdir, :test(/proto$/);

    for @files -> $path {
        g_ok(slurp($path), "parse {$path}");
    }
} else {
    say 'git is not installed... skipping official protobuf tests';
}

done-testing;
