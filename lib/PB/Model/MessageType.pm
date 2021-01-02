class PB::Model::MessageType {
    has Str $.name;
    has Bool $.is-stream;

    method new(Str :$name!, :$is-stream = False) {
        if !$name.chars {
            die "name must be a string of non-zero length";
        }
        self.bless(:$name, :$is-stream);
    }

    method gist() {
        "{$!is-stream ?? 'stream' !! ''} {$!name}";
    }
}

multi infix:<eqv>(PB::Model::MessageType $a, PB::Model::MessageType $b) is export {
    [&&]
        $a.name eq $b.name,
        $a.is-stream eqv $b.is-stream;
}
