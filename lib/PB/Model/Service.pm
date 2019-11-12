use PB::Model::Rpc;

class PB::Model::Service {
    has Str $.name;
    has PB::Model::Rpc @.rpcs;

    method new(Str :$name!, :@rpcs?) {
        if !$name.chars {
            die "name must be a string of non-zero length";
        }
        self.bless(:$name, :@rpcs);
    }

    method gist() {
        "<Service rpcs=[{join ', ', @.rpcs>>.gist}]>";
    }
}

multi infix:<eqv>(PB::Model::Service $a, PB::Model::Service $b) is export {
    [&&]
            $a.name eq $b.name,
            $a.rpcs eqv $b.rpcs;
}
