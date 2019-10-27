use Metamodel::Perlable;
use nqp;

use PB;
use PB::Grammar;
use PB::Actions;
use PB::Message;
use PB::Model::Package;
use PB::Model::Message;
use PB::RepeatClasses;

my Str constant ANON_NAME = '<anon>';

class PB::Model::Generator {
    has $.ast;
    has Str $.prefix;

    method all-classes {
        gather for $.ast -> $tlo { $.gen-class($tlo) }
    }

    method gen-class-name($obj) {
        # XXXX: What about class redefinition?
        # say 'prefix: ', $.prefix ~ $obj.name;
        $obj.name || ANON_NAME;
    }

    multi method gen-class(PB::Model::Package $pkg) {
        my $name  := $.gen-class-name($pkg);
        my $class := Metamodel::PerlableClassHOW.new_type(:$name);
        $class.HOW.add_parent($class, Any);

        $class.^compose;
        # say $class.^perl;
        take $name, $class;

        $.gen-class($_) for $pkg.messages;
    }

    multi method gen-class(PB::Model::Message $msg) {
        my class PB::Attribute is Attribute
            does Metamodel::PerlableAttribute {

            has Str         $.pb_type   is rw;
            has Str         $.pb_name   is rw;
            has Int         $.pb_number is rw;
            has RepeatClass $.pb_repeat is rw;
            has Bool        $.pb_packed is rw;

            method traits_perl() {
                my $traits = callsame;
                $traits ~= " is pb_type($.pb_type.perl())" if $.pb_type;
                $traits ~= " is pb_name($.pb_name.perl())" if $.pb_name;
                $traits ~= " is pb_number($.pb_number)"
                    if $.pb_number.defined;
                $traits ~= " is pb_repeat($.pb_repeat)"
                    if $.pb_repeat.defined;
                $traits ~= " is pb_packed" if $.pb_packed;
                $traits;
            }
        }

        my class PB::MessageClassHOW is Metamodel::PerlableClassHOW {
            has @!ordered-fields;
            has %!fields-by-tag;

            method ordered-fields($class) { @!ordered-fields }
            method fields-by-tag($class)  { %!fields-by-tag  }
            method compose(|) {
                my $class = callsame;

                @!ordered-fields =
                    self.attributes($class).grep(*.has_accessor)\
                    .grep({ $_.name !~~ m/'-'/ }).sort(*.pb_number);
                %!fields-by-tag{.pb_number} = $_ for @!ordered-fields;

                $class;
            }
        }

        my $class-name := $.gen-class-name($msg);
        my $class      := PB::MessageClassHOW.new_type(:name($class-name));
        $class.HOW.add_parent($class, PB::Message);

        for $msg.enums -> $enum {
            my $enum-name = $.gen-class-name($enum);
            my $enum-class = Metamodel::PerlableClassHOW.new_type(:name($enum-name));
            for $enum.fields -> $enum-field {
                # my $meth = method () is rw { $enum-field.value }
                # $meth.set_name($enum-field.name);
                $enum-class.HOW.add_method($enum-class, $enum-field.name,
                                           method () is rw { $enum-field.value });
            }
            # my $meth = method () is rw { $enum-class }
            # $meth.set_name($enum-name);
            $class.HOW.add_method($class, $enum-name,
                                  method () is rw { $enum-class });
        }

        for $msg.fields -> $field {
            my $pb_type = $field.type;
            my $type := do given $pb_type {
                when 'bool'           { Bool }
                when 'float'|'double' { Num  }
                when 'int32'|'uint32'|'sint32'|'fixed32'|'sfixed32'
                    |'int64'|'uint64'|'sint64'|'fixed64'|'sfixed64'
                                      { Int  }
                when 'string'         { Str  }
                when 'bytes'          { buf8 }
                # XXXX: Should this be PB::Message instead of Any?
                default               { Any  }
            };

            my $repeat := do given $field.label {
                when 'required' { RepeatClass::REQUIRED }
                when 'optional' { RepeatClass::OPTIONAL }
                when 'repeated' { RepeatClass::REPEATED }
            }

            my ($sigil, $container, $constraint);
            if $repeat ~~ RepeatClass::REPEATED {
                # XXXX: Specifically not parameterizing this to avoid
                # XXXX: constraint checking bugs and unintuitiveness
                $sigil       = '@';
                $container  := Array;
                $constraint := Positional;
            }
            else {
                $sigil       = '$';
                $container  := Scalar;
                $constraint := $type;
            }

            my $attr-name = $sigil ~ '!' ~ $field.name;
            my Mu $cd    := ContainerDescriptor.new(:name($attr-name), :dynamic,
                                                    :of($type),
                                                    :default($type));
            my Mu $cont  := nqp::create($container);
            nqp::bindattr($cont, $container, '$!descriptor', $cd);
            nqp::bindattr($cont, $container, '$!value', $type)
                if $container =:= Scalar;

            my Mu $attr  := PB::Attribute.new(:name($attr-name),
                                              :type($constraint),
                                              :package($class), :has_accessor,
                                              :auto_viv_container($cont),
                                              :container_descriptor($cd));
            $attr.pb_type   = $pb_type;
            $attr.pb_name   = $field.name;
            $attr.pb_number = $field.number;
            $attr.pb_repeat = $repeat;
            $attr.pb_packed = so $field.options.grep: *.name eq 'packed';
            $attr.set_rw;
            $class.^add_attribute($attr);
        }
        $class.^compose;
        # say $class.^perl;
        take $class-name, $class;
    }
}

# args = $filename!, $class-prefix?
our sub EXPORT(*@args) {
    # parse file and generate the AST
    # say @args;
    my $desc = slurp @args[0];
    my $actions := PB::Actions.new();
    my $ast := PB::Grammar.parse($desc, :$actions).ast;
    die "failed to parse {@args[0]}" unless $ast;

    # create a new class for everything in the ast
    my $gen = PB::Model::Generator.new(:$ast, :prefix(@args[1] // ''));

    # export these symbols
    %(gather for flat $gen.all-classes -> $name, $class {
        # say "GEN $name $class";
        take $name => $class unless $name eq ANON_NAME;
    });
}
