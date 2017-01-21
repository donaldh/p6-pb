use PB::Model::Option;

class PB::Model::Field {
    has Str $.label;
    has Str $.type;
    has Str $.name;
    has Int $.number;
    has PB::Model::Option @.options;

    method new(Str :$label!, Str :$type!, Str :$name!, Int :$number!, :@options?) {
        if !$label.chars || !$type.chars || !$name.chars {
            die "label, type, and name must all be a string with non-zero length";
        }
        self.bless(:$name, :$label, :$type, :$number, :@options);
    }

    method gist() {
        "<Field {$.name}={$.number} opts=[{@.options>>.gist}]>"
    }
}

multi infix:<eqv>(PB::Model::Field $a, PB::Model::Field $b) is export {
    [&&] $a.type eq $b.type,
         $a.name eq $b.name,
         $a.label eq $b.label,
         $a.number == $b.number,
         $a.options eqv $b.options;
}
