use v6;

use Test;
use Metamodel::Perlable;

plan(4);


{
    my class Test::BootAttr is Attribute
        does Metamodel::PerlableAttribute { }

    my $name  := 'Test::BootClass';
    my $class := Metamodel::PerlableClassHOW.new_type(:$name);
    $class.HOW.add_parent($class, Mu);

    my $foo := Test::BootAttr.new(:name<$!foo>, :type(str), :package($class));
    my $bar := Test::BootAttr.new(:name<$!bar>, :type(int), :package($class));
    my $baz := Test::BootAttr.new(:name<$!baz>, :type(num), :package($class));
    $baz.set_box_target; # box_target is ignored in Attribute.new

    $class.^add_attribute($_) for $foo, $bar, $baz;
    $class.^compose;

    my $class_perl := $class.^raku;
    is $class_perl, q:to/BOOT_PERL/, "Class with BOOTSTRAPATTR-based native attributes serializes to Raku code properly";
        class Test::BootClass {
            has str $!foo;
            has int $!bar;
            has num $!baz is box_target;
        }
        BOOT_PERL

    if $*VM.name eq 'jvm' {
        skip "rakudo-jvm NPE's when reading unassigned str attributes; see http://irclog.perlgeek.de/perl6/2013-11-14#i_7862142";
    }
    elsif $*VM.name eq 'moar' {
        skip "Disabling object with native attribute serialize test on MoarVM due to null native str attr";
    }
    else {
        my $obj := $class.new;
        my $obj_perl := $obj.^raku;
        is $obj_perl, q:to/BOOT_OBJ_PERL/, "Object with BOOTSTRAPATTR-based native attributes serializes to Raku code properly";
            class Test::BootClass {
                has str $!foo = "";
                has int $!bar = 0;
                has num $!baz is box_target = NaN;
            }
            BOOT_OBJ_PERL
    }
}


{
    # Testing regular extended Attributes

    #= An extended Attribute type for Test::Message attributes
    class Test::Metamodel::Attribute is Attribute
        does Metamodel::PerlableAttribute {

        has Bool $.frobulated is rw;

        method traits_raku() {
            my $traits = callsame;
            $traits ~= ' is frobulated' if $.frobulated;
        }
    }


    # A test message
    class Test::Message { }

    my $name  := 'Test::FooBar::BazQuux';
    my $class := Metamodel::PerlableClassHOW.new_type(:$name);
    $class.HOW.add_parent($class, Test::Message);

    my $attr  := Test::Metamodel::Attribute.new(:name<$!foo>, :package($class),
                                                :type(Str), :has_accessor);
    $attr.set_rw;
    $attr.frobulated = True;
    $class.^add_attribute($attr);
    $class.^compose;

    my $class_perl := $class.^raku;
    is $class_perl, q:to/CLASS_PERL/, "Class with extended attributes serializes to Raku code properly";
        class Test::FooBar::BazQuux is Test::Message {
            has Str $.foo is frobulated;
        }
        CLASS_PERL

    my $obj := $class.new(foo => 'bar');
    my $obj_perl := $obj.^raku;
    is $obj_perl, q:to/OBJ_PERL/, "Object with extended attributes serializes to Raku code properly";
        class Test::FooBar::BazQuux is Test::Message {
            has Str $.foo is frobulated = "bar";
        }
        OBJ_PERL
}


done-testing;
