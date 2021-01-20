use Test;
use PB::Grammar;
use PB::Actions;
use PB::Model::Field;
use PB::Model::Message;
use PB::Model::Option;
use PB::Model::Enum;
use PB::Model::Extension;
use PB::Model::Rpc;
use PB::Model::Service;

plan(119);

# Cribbed from Test.pm's is_deeply(), to work around a language limitation
# which prevents an independently compiled module (Test.pm in this case)
# from seeing multi candidates defined in a lexical scope it couldn't see
# at compile time.  See discussion starting at:
#     http://irclog.perlgeek.de/perl6/2013-10-06#i_7677518
sub is_eqv(Mu $got, Mu $expected, $reason = '') {
    my  $ok = ok($got eqv $expected, $reason);
    if !$ok {
        my $got_perl      = try { $got.perl };
        my $expected_perl = try { $expected.perl };
        if $got_perl.defined && $expected_perl.defined {
            diag "     got: $got_perl";
            diag "expected: $expected_perl";
        }
    }
    return $ok;
}

sub isnt_eqv(Mu $got, Mu $expected, $reason = '') {
    return nok($got eqv $expected, $reason);
}

# tests a grammer rule for an expected output
sub gr_ok($text, $rule, $expected, $desc?) {
    my $actions = PB::Actions.new;
    my $result = PB::Grammar.parse($text, :$rule, :$actions).ast;
    return is_eqv($result, $expected, $desc);
}

# string constants
{
    gr_ok '"hello"', <str-lit>, "hello", "str-lit basic";
    gr_ok '"hello \xc3"', <str-lit>, "hello \xc3", "str-lit unicode escape";
    gr_ok "'\\176'", <str-lit>, "~", 'str-lit oct escape, single-quote';
    gr_ok "'\\n'", <str-lit>, "\n", 'str-lit newline escape';
    gr_ok '"\\\\"', <str-lit>, '\\', 'str-lit double backslash escape';
    # TODO: test the other backslash char escapes
}

# number constants
{
    gr_ok "1", <constant>, 1, 'int-lit basic decimal';
    gr_ok "0xf4", <constant>, 244, 'int-lit basic hex';
    gr_ok "070", <constant>, 56, 'int-lit basic oct';
    gr_ok "1.0", <constant>, 1.0e0, 'constant float';
    gr_ok "1.0e40", <constant>, 1.0e40, 'constant exponential float';
    gr_ok ".01", <constant>, 0.01e0, 'constant float w/o leading zero';
    gr_ok 'false', <constant>, False, 'constant false';
    gr_ok 'true', <constant>, True, 'constant true';
    gr_ok 'inf', <constant>, Inf, 'constant positive Inf';
    gr_ok '+inf', <constant>, Inf, 'constant positive Inf with sign';
    gr_ok '-inf', <constant>, -Inf, 'constant negative Inf with sign';
    gr_ok 'nan', <constant>, NaN, 'constant nan';
}

# PB::Model::Option
{
    nok (try PB::Model::Option.new(name => 'x')), 'construct option w/o constant or sub message';
    ok PB::Model::Option.new(name => 'y', constant => 1.0e4), 'construct option w/ constant';
    ok PB::Model::Option.new(name => 'y', constant => 0), 'construct option w/ falsey constant';
    nok (try PB::Model::Option.new(name => 'x', sub-message => PB::SubMesg.new(), constant=> 'x')), 'dont construct option with both constant and sub message';
    # todo: construct / equality tests for options with sub messages
    is_eqv PB::Model::Option.new(name => 'x', constant => 'a'), PB::Model::Option.new(name => 'x', constant => 'a'), 'option equal';
    isnt_eqv PB::Model::Option.new(name => 'x', constant => 'a'), PB::Model::Option.new(name => 'y', constant => 'a'), 'option not equal';
    is_eqv PB::Model::Option.new(name => 'x', constant => 'y'), PB::Model::Option.new(name => 'x', constant => 'y'), 'option w/ constant equal';
    isnt_eqv PB::Model::Option.new(name => 'x', constant => 0), PB::Model::Option.new(name => 'x', constant => 1), 'option w/ constant equal';
    nok (try PB::Model::Option.new(:name(''), :constant(''))), 'option with empty string name';

    # parsing
    gr_ok 'option x = 1;', <option>, PB::Model::Option.new(name => 'x', constant => 1), 'option int const';
    gr_ok 'option x = 1.0;', <option>, PB::Model::Option.new(name => 'x', constant => 1.0e0), 'option float const';
    gr_ok 'option x = 0xf4;', <option>, PB::Model::Option.new(name => 'x', constant => 244), 'option hex const';
    gr_ok 'option x = 070;', <option>, PB::Model::Option.new(name => 'x', constant => 56), 'option opt const';
    gr_ok 'option x = -.2e5;', <option>, PB::Model::Option.new(name => 'x', constant => -.2e5), 'option float exponent';
    gr_ok 'option x = false;', <option>, PB::Model::Option.new(name => 'x', constant => False), 'option false';
    gr_ok 'option x = true;', <option>, PB::Model::Option.new(name => 'x', constant => True), 'option true';
    gr_ok 'option x = inf;', <option>, PB::Model::Option.new(name => 'x', constant => Inf), 'option inf';
    gr_ok 'option x = -inf;', <option>, PB::Model::Option.new(name => 'x', constant => -Inf), 'option -inf';
    gr_ok 'option x = nan;', <option>, PB::Model::Option.new(name => 'x', constant => NaN), 'option NaN';
}

# PB::Model::Field
{
    nok (try PB::Model::Field.new()), 'empty field constructor';
    nok (try PB::Model::Field.new(name=>'name')), 'field constructor w/o label, type or number';
    nok (try PB::Model::Field.new(name=>'name', label=>'required')), 'field constructor w/o type or number';
    nok (try PB::Model::Field.new(name=>'name', label=>'required', type=>'int32')), 'field constructor w/o number';
    ok PB::Model::Field.new(name=>'name', label=>'required', type=>'int32', number=>1), 'valid field constructor';
    ok PB::Model::Field.new(name=>'name', label=>'required', type=>'int32', number=>1, 
        options=>[PB::Model::Option.new(name=>'x', constant=>'x')]), 'field constructor with options';
    nok (try PB::Model::Field.new(:name(''), :label(''), :type(''), :number(1))), 'field constructor with empty values';

    # equality
    my $field = PB::Model::Field.new(name=>'name', label=>'required', type=>'int32', number=>1);
    my $field2 = PB::Model::Field.new(name=>'name', label=>'required', type=>'int32', number=>1);
    my $fopt = PB::Model::Option.new(name=>'default', constant=>0);
    my $fopt2 = PB::Model::Option.new(name=>'default', constant=>0);
    is_eqv (my PB::Model::Option @ = $fopt,), (my PB::Model::Option @ = $fopt2,), 'option equality sanity test';
    is_eqv $fopt, $fopt2, 'option equality sanity test, unwrapped';

    is_eqv $field, $field, 'field equality to self';
    is_eqv $field, $field2, 'basic field equality';
    isnt_eqv $field, $field2.clone(number=>2), 'field non-equality with different numbers';
    isnt_eqv $field, $field2.clone(name=>'othername'), 'field non-equality with different names';
    isnt_eqv $field, $field2.clone(label=>'optional'), 'field non-equality with different labels';
    isnt_eqv $field, $field2.clone(:options($fopt)), 'field non-equality one with and one without options';
    is_eqv $field.clone(:options($fopt)), $field2.clone(:options($fopt2)), 'field equality with same options';
    isnt_eqv $field.clone(:options($fopt.clone(constant=>1))), $field2.clone(:options($fopt2)), 'field non-equality with different options';
}

# PB::Model::EnumField
{
    nok (try PB::Model::EnumField.new()), 'enum field constructor must take name and value';
    nok (try PB::Model::EnumField.new(name=>'hello')), 'enum field constructor must take value';
    nok (try PB::Model::EnumField.new(value=>1)), 'enum field constructor must take name';
    nok (try PB::Model::EnumField.new(name=>'x', value=>'1')), 'enum field constructor must take an int value [str provided]';
    nok (try PB::Model::EnumField.new(name=>'x', value=>1.0)), 'enum field constructor must take an int value [float provided]';
    ok PB::Model::EnumField.new(name=>'x', value=>1), 'enum field regular constructor works';
    ok PB::Model::EnumField.new(name=>'x', value=>1, options=>[PB::Model::Option.new(name=>'default', constant=>1)]), 'enum create w/ options';

    # equality
    my $efieldopt = PB::Model::Option.new(name=>'default', constant=>1);
    my $efield = PB::Model::EnumField.new(name=>'hello', value=>1);
    my $efield2 = $efield.clone();

    is_eqv $efield, $efield2, 'enum field equality';
    isnt_eqv $efield, $efield.clone(value=>2), 'enum field name inequality';
    isnt_eqv $efield, $efield.clone(name=>'not hello'), 'enum field name inequality';
    isnt_eqv $efield, $efield.clone(options=>[$efieldopt]), 'enum field option inequality';
    is_eqv $efieldopt, $efieldopt.clone, "opt clone equality sanity test";
    is_eqv $efield.clone(:options($efieldopt)), $efield.clone(:options($efieldopt.clone)), 'enum field option equality';
}

# PB::Model::Enum
{
    # construction
    my $fopt = PB::Model::Option.new(name=>'default', constant=>0);
    my $efield = PB::Model::EnumField.new(name=>'hello', value=>1);
    nok (try PB::Model::Enum.new()), 'enum w/o name';
    ok PB::Model::Enum.new(name=>'hello'), 'enum with only name';
    ok PB::Model::Enum.new(name=>'hello', options=>[$fopt]), 'enum with an option';
    ok PB::Model::Enum.new(name=>'hello', fields=>[$efield]), 'enum with a field';
    ok PB::Model::Enum.new(name=>'hello', options=>[$fopt], fields=>[$efield]), 'enum with a field an an option';

    # equality
    my $eopt = PB::Model::Option.new(name=>'default', constant=>0);
    my $enum = PB::Model::Enum.new(name=>'hello', options=>[$eopt], fields=>[$efield]);
    my $enum2 = $enum.clone();

    is_eqv $enum, $enum2, 'enum equality';
    isnt_eqv $enum, $enum2.clone(name=>'shit'), 'enum name inequality';

    my $efield3 = $efield.clone(name=>'not hello');
    isnt_eqv $efield, $efield3, 'field clone sanity test';
    my $enum3 = $enum2.clone(:fields($efield3));
    isnt_eqv $enum2, $enum3, 'enum clone sanity test';

    isnt_eqv $enum, ($enum2.clone(:fields($efield.clone(name=>'not hello')))), 'enum fields inequality';
    isnt_eqv $enum, $enum3, 'enum fields inequality';
    isnt_eqv $enum, $enum2.clone(:options($eopt.clone(constant=>1))), 'enum opts inequality';

    # parsing
    gr_ok 'enum TEST { }', <enum>, PB::Model::Enum.new(name=>'TEST'), 'basic empty enum creation';
    gr_ok 'enum TEST { VAL = 1; }', <enum>,
        PB::Model::Enum.new(name=>'TEST', fields=>[PB::Model::EnumField.new(name=>'VAL', value=>1)]),
        'enum with a field creation';
    gr_ok 'enum Omg { INTLOL = 1; STRLOL = 2 [default=INTLOL]; }', <enum>,
        PB::Model::Enum.new(name=>'Omg', fields=>[
            PB::Model::EnumField.new(name=>'INTLOL', value=>1),
            PB::Model::EnumField.new(name=>'STRLOL', value=>2, options=>[
                PB::Model::Option.new(name=>'default', constant=>'INTLOL')])]),
        'enum with two fields, one with an option';
}

# PB::Model::ExtensionField
{
    # construction
    ok PB::Model::ExtensionField.new(start=>999, end=>9999), 'extension field regular construction';
    nok (try PB::Model::ExtensionField.new(end=>0)), 'extension field missing start';
    nok (try PB::Model::ExtensionField.new()), 'extension field missing both';
    # equality
    my $extf = PB::Model::ExtensionField.new(start=>0, end=>1);
    my $extf2 = $extf.clone();
    is_eqv $extf, $extf2, 'extension field equality';
    isnt_eqv $extf, $extf2.clone(end=>2), 'extension field end inequality';
    isnt_eqv $extf, $extf2.clone(start=>1), 'extension field start inequality';
    is_eqv PB::Model::ExtensionField.new(start=>1), PB::Model::ExtensionField.new(start=>1), 'extension field equality without an end';
    isnt_eqv PB::Model::ExtensionField.new(start=>2), PB::Model::ExtensionField.new(start=>1), 'extension field inequality without an end';

    # parsing
    gr_ok '1 to 2', <extension>, PB::Model::ExtensionField.new(start=>1, end=>2), 'extension field regular parse';
    gr_ok '1 to max', <extension>, PB::Model::ExtensionField.new(start=>1, end=>PB::Model::ExtensionField::MAX), 'extension field to max';
    gr_ok '99999 to 999999', <extension>, PB::Model::ExtensionField.new(start=>99999, end=>999999), 'extension field large numbers';
    gr_ok '1', <extension>, PB::Model::ExtensionField.new(start=>1), 'extension field w/o end';
}

# PB::Model::Message
{
    # construction
    my $mfield = PB::Model::Field.new(name=>'fieldname', label=>'required', type=>'int32', number=>1);
    ok PB::Model::Message.new(:name<a>, :fields()), 'message w/ no fields';
    ok PB::Model::Message.new(:name<a>, :fields([$mfield])), 'message w/ a field';
    nok (try PB::Model::Message.new(:name(''))), 'message requires a name';

    my $msg = PB::Model::Message.new(:name<a>, :fields[$mfield]);
    my $msg2 = PB::Model::Message.new(:name<a>, :fields[$mfield]);
    my $msg3 = PB::Model::Message.new(:name<a>, :fields[$mfield.clone(:name<otherfieldname>)]);

    # equality
    is_eqv $msg, $msg2, 'message equality';
    isnt_eqv $msg, $msg3, 'message inequality';
    isnt_eqv $msg, $msg.clone(:name<b>), 'message name inequality';
    is_eqv PB::Model::Message.new(:name<a>), PB::Model::Message.new(:name<a>), 'empty message equality';

    # w/ enum
    my $menum = PB::Model::Enum.new(name=>'KIND', fields=>[PB::Model::EnumField.new(name=>'STR', value=>1)]);
    my $menum2 = PB::Model::Enum.new(name=>'KIND', fields=>[PB::Model::EnumField.new(name=>'INT', value=>1)]);
    isnt_eqv $menum, $menum2, 'message enum inequality sanity check';

    $msg = PB::Model::Message.new(:name<a>, :enums[$menum]);
    $msg2 = $msg.clone(:enums[$menum2]);

    isnt_eqv $msg, $msg2, 'message enum inequality';
    is_eqv $msg, $msg.clone(:enums($menum)), 'message enum equality';

    # with a contained message
    my $mmessage = PB::Model::Message.new(name=>'hello', fields=>[
        PB::Model::Field.new(label=>'required', type=>'int32', name=>'helloval', number=>1)]);
    my $mmessage2 = $mmessage.clone(:fields($mmessage.fields[0].clone(:label<optional>)));

    isnt_eqv $mmessage, $mmessage2, 'message containing message inequality - sanity test';
    is_eqv $mmessage, $mmessage2.clone(:fields($mmessage.fields[0].clone)), 'message containing message equality - sanity test';

    my $mmsg = PB::Model::Message.new(name=>'X', messages=>[$mmessage]);
    my $mmsg2 = PB::Model::Message.new(name=>'X', messages=>[$mmessage2]);

    isnt_eqv $mmsg, $mmsg2, 'message containing message inequality';
    is_eqv $mmsg, $mmsg2.clone(:messages($mmsg.messages[0].clone)), 'message containing message equality';

    # message w/ extensions
    ok PB::Model::Message.new(name=>'hello', extensions=>[PB::Model::ExtensionField.new(start=>1)]), 'message creation w/ extension';
    my $emsg = PB::Model::Message.new(:name<a>, :extensions([PB::Model::ExtensionField.new(start=>1)]));
    my $emsg2 = $emsg.clone(:extensions($emsg.extensions[0].clone(start=>2)));
    isnt_eqv $emsg, $emsg2, 'message w/ extension inequality';
    is_eqv $emsg, $emsg2.clone(:extensions($emsg.extensions[0])), 'message w/ extensions equality';
}

# PB::Model::Message parsing
{
    gr_ok 'message n{required int32 x=1;}', <message>, 
        PB::Model::Message.new(name=>'n', fields=>[
            PB::Model::Field.new(label=>'required', type=>'int32', name=>'x', number=>1)]),
        'basic message field parsing';

    gr_ok 'message n{
            optional string mylabel = 1 [default="farting"];
            optional float mylabel2 = 2;
            }', 
        <message>,
        PB::Model::Message.new(name=>'n', fields=>[
            PB::Model::Field.new(label=>'optional', type=>'string', name=>'mylabel', number=>1, 
                options=>[PB::Model::Option.new(name=>'default', constant=>"farting")]),
            PB::Model::Field.new(label=>'optional', type=>'float', name=>'mylabel2', number=>2)
        ]),
        'message w/ multiple fields, one with an option';

    gr_ok 'message N{enum X{}}', <message>,
        PB::Model::Message.new(name=>'N', enums=>[PB::Model::Enum.new(name=>'X')]),
        'message w/ enum';

    gr_ok 'message M{message X{enum Y{ Z = 1; }}}', <message>,
        PB::Model::Message.new(name=>'M', messages=>[
            PB::Model::Message.new(name=>'X', enums=>[
                PB::Model::Enum.new(name=>'Y', fields=>[PB::Model::EnumField.new(name=>'Z', value=>1)])])]),
        'message w/ message w/ enum w/ field';

    is_eqv PB::Model::Message.new(name=>'M', extensions=>[
            PB::Model::ExtensionField.new(start=>1, end=>100)]), PB::Model::Message.new(name=>'M', extensions=>[
            PB::Model::ExtensionField.new(start=>1, end=>100)]), 'message w/ extension cmp sanity';

    gr_ok 'message M{extensions 1 to 100;}', <message>,
        PB::Model::Message.new(name=>'M', extensions=>[
            PB::Model::ExtensionField.new(start=>1, end=>100)]),
        'message w/ extensions';

    gr_ok 'message M{extensions 1 to 100; extensions 101 to max; }', <message>,
        PB::Model::Message.new(name=>'M', extensions=>[
            PB::Model::ExtensionField.new(start=>1, end=>100),
            PB::Model::ExtensionField.new(start=>101, end=>PB::Model::ExtensionField::MAX)]),
        'message w/ 2 extensions (one of which is MAX)';
}

# PB::Model::Service parsing
{
    gr_ok 'service SearchService { rpc Search (SearchRequest) returns (SearchResponse); }', <service>,
            PB::Model::Service.new(name => 'SearchService', rpcs => [
                PB::Model::Rpc.new(
                        name => 'Search',
                        input => PB::Model::MessageType.new(name => 'SearchRequest'),
                        output => PB::Model::MessageType.new(name => 'SearchResponse'))
            ]),
            'service w/ single rpc';

    gr_ok 'service SearchService { rpc Search (stream SearchRequest) returns (stream SearchResponse); }', <service>,
            PB::Model::Service.new(name => 'SearchService', rpcs => [
                PB::Model::Rpc.new(
                        name => 'Search',
                        input => PB::Model::MessageType.new(name => 'SearchRequest'),
                        output => PB::Model::MessageType.new(name => 'SearchResponse'))
            ]),
            'service w/ single stream rpc';
}
