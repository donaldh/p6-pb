use PB::Model::SubMessage;

class PB::Model::Option {
    has Str $.name;
    has $.constant;
    has PB::Model::SubMessage $.sub-message;

    method new(Str :$name!, :$constant?, PB::Model::SubMessage :$sub-message?) {
        if !$name.chars {
            die "name must not be zero length";
        }
        if !($constant.defined ?^ $sub-message.defined) {
            die "either constant OR sub-message must be provided, not both";
        }
        self.bless(:$name, :$constant, :$sub-message);
    }

    method gist() {
        "<Option $.name={$.constant // 'Any'}>"
    }
}

multi infix:<eqv>(PB::Model::Option $a, PB::Model::Option $b) is export {
    [&&] $a.name eq $b.name,
         $a.constant eqv $b.constant,
         $a.sub-message eqv $b.sub-message;
}
