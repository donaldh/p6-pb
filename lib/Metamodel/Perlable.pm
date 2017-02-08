use v6;
use nqp;

#= Composed into an Attribute subclass to serialize the attribute definitions to Perl source
role Metamodel::PerlableAttribute {
    method traits_perl(Metamodel::PerlableAttribute:D:) {
        my $traits = '';
        $traits ~= ' is rw'         if nqp::can(self, 'rw') && self.rw;
        $traits ~= ' is box_target' if self.box_target;
        $traits;
    }

    method perl(Metamodel::PerlableAttribute:D:) {
        my $has_cd = nqp::can(self, 'container_descriptor');
        my $of     = $has_cd ?? self.container_descriptor.of !! self.type;
        my $type   = $of.HOW.name($of);
        my $name   = self.name;
           $name  .= subst('!', '.') if self.has_accessor;
        my $traits = self.traits_perl;

        "has $type $name$traits";
    }
}


#= Composed into a Metamodel::ClassHOW subclass to serialize class definitions to Perl source
role Metamodel::PerlableClass {
    multi method perl(Mu $class) {
        my $perl = "class $class.^name()";
        $perl ~= " is $_.^name()"   for $class.^parents;
        $perl ~= " does $_.^name()" for $class.^roles;
        $perl ~= " \{\n";
        for $class.^attributes.grep(Metamodel::PerlableAttribute) -> $attr {
            my $attr_perl = $attr.perl;
            if $class.defined {
                my $attr_name = $attr.name;
                my $has_value = True;

                # Code to get a value from recalcitrant attributes adapted from Mu.DUMP()
                my Mu $value;
                if    $attr.has_accessor {
                    $value := $class."$attr_name.substr(2)"();
                }
                elsif nqp::can($attr, 'get_value') {
                    $value := $attr.get_value($class);
                }
                elsif nqp::can($attr, 'package') {
                    my Mu $decont  := nqp::decont($class);
                    my Mu $package := $attr.package;

                    $value := do given nqp::p6box_i(nqp::objprimspec($attr.type)) {
                        when 0 {              nqp::getattr(  $decont, $package, $attr_name)  }
                        when 1 { nqp::p6box_i(nqp::getattr_i($decont, $package, $attr_name)) }
                        when 2 { nqp::p6box_n(nqp::getattr_n($decont, $package, $attr_name)) }
                        when 3 { nqp::p6box_s(nqp::getattr_s($decont, $package, $attr_name)) }
                    };
                }
                else {
                    $has_value = False;
                }

                $attr_perl ~= " = $value.perl()" if $has_value;
            }
            $perl ~= "    $attr_perl;\n";
        }
        $perl ~= "}\n";
        $perl;
    }
}


#= A metaclass for classes whose definition can be serialized into Perl source
class Metamodel::PerlableClassHOW
    is   Metamodel::ClassHOW
    does Metamodel::PerlableClass { }
