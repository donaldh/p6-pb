use PB::Grammar;
use PB::Model::Field;
use PB::Model::Message;
use PB::Model::Option;
use PB::Model::Package;
use PB::Model::Enum;
use PB::Model::Extension;


class PB::Actions {
    method TOP($/) {
        make $<proto>.ast;
    }

    method proto($/) {
        my $pkg = '';
        if $<pkg>[0] {
            $pkg = $<pkg>[0]<dotted-ident>.Str
        }
        make PB::Model::Package.new(
            name => $pkg,
            messages => $<message>>>.ast,
            options => $<option>>>.ast,
            enums => $<enum>>>.ast
        );
    }

    method option($/) {
        make $<opt-body>.ast;
    }

    method enum($/) {
        make PB::Model::Enum.new(
            name => $<ident>.Str,
            options => $<option>>>.ast,
            fields => $<enum-field>>>.ast
        );
    }

    method enum-field($/) {
        make PB::Model::EnumField.new(
            name => $<ident>.Str,
            value => $<int-lit>.Num.Int,
            options => $<field-opts> ?? $<field-opts>.ast !! []
        );
    }

    method message($/) {
        make PB::Model::Message.new(
            name => $<ident>.Str,
            fields => $<message-body><field>>>.ast,
            enums => $<message-body><enum>>>.ast,
            messages => $<message-body><message>>>.ast,
            extensions => $<message-body><extensions>>>.ast
        );
    }

    method field($/) {
        make PB::Model::Field.new(
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
        make PB::Model::Option.new(
            name => $<opt-name>.Str,
            constant => $<constant> ?? $<constant>.ast !! Any
        );
    }

    method extensions($/) {
        make $<extension>.ast;
    }

    method extension($/) {
        my $end;
        if $<end> && $<end>.Str eq 'max' {
            $end = PB::Model::ExtensionField::MAX;
        } elsif $<end> {
            $end = $<end>.Str.Int;
        }
        my %args = %('start' => $<start>.Str.Int);
        if $end {
            %args{'end'} = $end;
        }
        make PB::Model::ExtensionField.new(|%args);
    }

    # other constants ---------------------------------------------------------

    method constant:sym<symbol>($/) {
        make $<ident>.Str;
    }

    # string constants --------------------------------------------------------

    method constant:sym<str>($/) {
        make $<str-lit>.ast;
    }

    method str-lit:sym<single-quoted>($/) {
        make $<str-contents-single>.flat>>.ast.join;
    }

    method str-lit:sym<double-quoted>($/) {
        make $<str-contents-double>.flat>>.ast.join;
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
        make chr(:16(~$<xdigit>.join));
    }

    method str-escape:sym<oct>($/) {
        make chr(:8(~$<digit>));
    }

    method str-escape:sym<char>($/) {
        my %h = 
            'n' => "\n",
            '\\' => "\\",
            # TODO: others...
        ;
        make %h{~$<char>};
    }

    # number constants --------------------------------------------------------

    method constant:sym<int>($/) {
        make $<int-lit>.ast;
    }

    method int-lit:sym<dec>($/) {
        make $/.Str.Int;
    }

    method int-lit:sym<hex>($/) {
        make :16($<xdigit>.join);
    }

    method int-lit:sym<oct>($/) {
        make :8(~$<digit> || '0');
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
