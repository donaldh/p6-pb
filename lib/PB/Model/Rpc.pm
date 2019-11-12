use PB::Model::Extension;

class PB::Model::Rpc {
    has Str $.name;
    has Str $.input;
    has Str $.output;
    has PB::Model::ExtensionField @.extensions;

    method new(Str :$name!, :$input!, :$output!, :@extensions) {
        if !$name.chars {
            die "name must be a string of non-zero length";
        }
        self.bless(:$name, :$input, :$output, :@extensions);
    }

    method gist() {
        "<Rpc in=[{$!input.gist}] out=[{$!output.gist}]>";
    }
}

multi infix:<eqv>(PB::Model::Rpc $a, PB::Model::Rpc $b) is export {
    [&&]
            $a.name eq $b.name,
            $a.input eqv $b.input,
            $a.output eqv $b.output,
            $a.extensions eqv $b.extensions;
}
