use PB::Model::Field;
use PB::Model::Enum;
use PB::Model::Extension;

class PB::Model::Message {
    has Str $.name;
    has PB::Model::Field @.fields;
    has PB::Model::Enum @.enums;
    has PB::Model::Message @.messages;
    has PB::Model::ExtensionField @.extensions;

    method new(Str :$name!, :@fields?, :@enums?, :@messages?, :@extensions?) {
        if !$name.chars {
            die "name must be a string of non-zero length";
        }
        self.bless(:$name, :@fields, :@enums, :@messages, :@extensions);
    }

    method gist() {
        "<Message fields=[{join ', ', @.fields>>.gist}]>";
    }
}

multi infix:<eqv>(PB::Model::Message $a, PB::Model::Message $b) is export {
    [&&] flat
        $a.name eq $b.name,
        $a.enums eqv $b.enums,
        $a.fields eqv $b.fields,
        $a.messages eqv $b.messages,
        $a.extensions eqv $b.extensions;
}

multi infix:<eqv>(PB::Model::Message @a, PB::Model::Message @b) is export {
    @a.elems == @b.elems && @a Zeqv @b;
}
