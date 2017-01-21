use PB::Model::Option;

class PB::Model::EnumField {
    has Str $.name;
    has Int $.value;
    has PB::Model::Option @.options;

    method new(Str :$name!, Int :$value!, :@options?) {
        self.bless(:$name, :$value, :@options);
    }
}

multi infix:<eqv>(PB::Model::EnumField $a, PB::Model::EnumField $b) is export {
    [&&]
        $a.name eq $b.name,
        $a.value == $b.value,
        $a.options eqv $b.options;
}


class PB::Model::Enum {
    has Str $.name;
    has PB::Model::Option @.options;
    has PB::Model::EnumField @.fields;

    method new(Str :$name!, :@options?, :@fields?) { # todo: put type qualifiers on these params, when it works in rakudo again
        die "name is required to be a string of non-zero length" unless $name.chars;
        self.bless(:$name, :@options, :@fields);
    }
}

multi infix:<eqv>(PB::Model::Enum $a, PB::Model::Enum $b) is export {
    [&&]
        $a.name eq $b.name,
        $a.fields eqv $b.fields,
        $a.options eqv $b.options;
}
