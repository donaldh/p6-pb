use PB::Grammar;

class PB::SubMsg {

}

class PB::Option {
    has Str $.name;
    has $.constant;
    has PB::SubMsg $.sub-message;
    
    method new(Str :$name!, :$constant?, PB::SubMsg :$sub-message?) {
        if (!$constant.defined && !$sub-message.defined) || ($constant.defined && $sub-message.defined) {
            die "either constant OR sub-message must be provided"; 
        }
        self.bless(*, name => $name, constant => $constant, sub-message => $sub-message);
    }

    method gist() {
        "<Option {$.name}={$.constant.defined ?? $.constant !! 'Any'}>"
    }
}

multi infix:<eq>(PB::Option $a, PB::Option $b) is export {
    # say "$a = $b";
    return
        [&&] ($a.name eq $b.name),
             ($a.constant // Nil) eq ($b.constant // Nil),
             ($a.sub-message // Nil) eq ($b.sub-message // Nil);
}

class PB::Field {
    has Str $.label;
    has Str $.type;
    has Str $.name;
    has Int $.number;
    has Array[PB::Option] @.options;

    method new(Str :$label!, Str :$type!, Str :$name!, Int :$number!, :@options) {
        self.bless(*, name => $name, label => $label, type => $type, number => $number, options => @options);
    }

    method gist() {
        "<Field {$.name}={$.number} opts=[{@.options>>.gist}]>"
    }
}

multi infix:<eq>(PB::Field $a, PB::Field $b) is export {
    my @aopts = ($a.options // []);
    my @bopts = ($b.options // []);
    return 
        [&&] ($a.label eq $b.label),
             ($a.type eq $b.type),
             ($a.name eq $b.name),
             ($a.number eq $b.number),
             [&&](@aopts Zeq @bopts),
             (@aopts == @bopts);
}

class PB::Message {
    has Array[PB::Field] @.fields;

    method gist() {
        "<Message fields=[{join ', ', @.fields>>.gist}]>";
    }
}

class PB::Package { 
    has Str $.name;
    has Array[PB::Message] @.messages;
    has Array[PB::Option] @.options;

    method gist() {
        "<Package {$.name} messages=[{join ', ', @.messages>>.gist}]>"
    }
}

class PB::Actions {
    method TOP($/) {
        make $<proto>.ast;
    }

    method proto($/) {
        make PB::Package.new(
            name => $<pkg>[0]<dotted-ident>.Str,
            messages => $<message>>>.ast,
            options => $<option>>>.ast
        );
    }

    method option($/) {
        make $<opt-body>.ast;
    }

    method message($/) {
        make PB::Message.new(
            fields => $<message-body><field>>>.ast
        );
    }

    method field($/) {
        make PB::Field.new(
            label => $<label>.Str, 
            type => $<type>.Str,
            name => $<ident>.Str,
            number => $<field-num>.Num.Int,
            options => $<field-opts> ?? $<field-opts>.ast !! []
        );
    }

    method field-opts($/) {
        make $<opt-body>>>.ast;
    }

    method field-opt($/) {
        make $<opt-body>.ast;
    }

    method opt-body($/) {
        make PB::Option.new(
            name => $<opt-name>.Str,
            constant => $<constant> ?? $<constant>.ast !! Any
        );
    }

    ## string constants -------------------------------------------------------

    method constant:sym<str>($/) {
        make $<str-lit>.ast;
    }

    method str-lit:sym<single-quoted>($/) {
        make $<str-contents-single>>>.flat>>.ast.join;
    }

    method str-lit:sym<double-quoted>($/) {
        make $<str-contents-double>>>.flat>>.ast.join;
    }

    method str-contents-single($/) {
        if $<str-escape> {
            make $<str-escape>.ast;
        } else {
            make ~$/;
        }
    }

    method str-contents-double($/) {
        if $<str-escape> {
            make $<str-escape>.ast;
        } else {
            make ~$/;
        }
    }

    method str-escape:sym<hex>($/) {
        make chr(:16($<xdigit>.join));
    }

    method str-escape:sym<oct>($/) {
        make chr(:8($<digit>.join));
    }

    method str-escape:sym<char>($/) {
        my %h = {
            'n' => "\n",
            '\\' => "\\",
            # TODO: others...
        };
        make %h{~$<char>};
    }

    # number constants --------------------------------------------------------

    method constant:sym<int>($/) {
        make $<int-lit>.ast;
    }

    method int-lit:sym<dec>($/) {
        make $/.Str.Num;
    }

    method int-lit:sym<hex>($/) {
        make :16($<xdigit>.join);
    }

    method int-lit:sym<oct>($/) {
        make :8($<digit>.join);
    }

    method constant:sym<nan>($/) {
        make NaN;
    }

    method constant:sym<inf>($/) {
        if $<sign> && $<sign>.Str eq '-' {
            make -Inf;
        } else {
            make Inf;
        }
    }

    method constant:sym<bool>($/) {
        if $/.Str eq 'true' {
            make Bool::True;
        } else {
            make Bool::False;
        }
    }

    method constant:sym<float>($/) {
        make $/.Str.Num;
    }
}

my $actions = PB::Actions.new;
my $src = '
package omg.nowai;

message yawai {
    required int32 lolwut = 1 [default="snarf \x14b stoor \n", butt=LOL_NOWAI, hart=\'art\'];
    optional string snu = 2 [default=1];
}
';
# say 'parse: ', PB::Grammar.parse($src);
# say 'act: ', PB::Grammar.parse($src, :actions($actions)).ast;

# ==> use of uninitialized value of type Any in string context  in block  at lib/PB/Actions.pm:23
