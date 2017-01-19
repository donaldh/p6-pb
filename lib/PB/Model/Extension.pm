use PB::Model::Field;

class PB::Model::Extension {
    has Str $.name; # original message name
    has PB::Model::Field @.fields;

    method new(Str :$name!, :@fields?) {
        die "name must be a string of non-zero length" unless $name.chars;
        self.bless(:$name, :@fields);
    }

    method gist() {
        "<Extension {$.name}={$.number} opts=[{@.options>>.gist}]>"
    }
}

multi infix:<eqv>(PB::Model::Extension $a, PB::Model::Extension $b) is export {
    [&&] flat
        $a.name eq $b.name,
        $a.fields eqv $b.fields;
}

multi infix:<eqv>(PB::Model::Extension @a, PB::Model::Extension @b) is export {
   [&&] flat
       @a.elems == @b.elems,
       @a Zeqv @b;
}


class PB::Model::ExtensionField {
    # the maximum extension number
    our Int constant MAX = 536_870_911;

    has Int $.start;
    has Int $.end;

    method new (Int :$start!, Int :$end?) {
        self.bless(:$start, :$end);
    }
}

multi infix:<eqv>(PB::Model::ExtensionField $a, PB::Model::ExtensionField $b) is export {
    $a.start == $b.start && ((!$a.end && !$b.end) || $a.end == $b.end);
}

multi infix:<eqv>(PB::Model::ExtensionField @a, PB::Model::ExtensionField @b) is export {
    [&&] flat
        @a.elems == @b.elems,
        @a Zeqv @b;
}
