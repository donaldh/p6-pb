use PB::Grammar;
use PB::Actions;

unit module PB;

use Grammar::Tracer;

sub parse-idl-str($protofile) is export {
    my $actions = PB::Actions.new();
    my $result;
    die "unable to parse file" 
        unless $result = PB::Grammar.parse($protofile, :$actions);
    $result.ast;
}

sub parse-idl-file($filename) is export {
    my $protofile = slurp(open $filename);
    parse-idl-str($protofile);
}
