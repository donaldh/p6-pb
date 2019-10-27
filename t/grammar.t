use Test;
use PB::Grammar;

# to automate the testing of this grammar
sub g_ok (Str $testme, Str $desc?) { ok PB::Grammar.parse($testme), $desc; }
sub g_nok (Str $testme, Str $desc?) { nok PB::Grammar.parse($testme), $desc; }

g_nok 'package .omgnowai;',                 'package name should not start with a dot';
g_ok 'package omgnowai;',                   'package name parses correctly';
g_nok 'package omgnowai',                   'package must have a semicolon at the end';
g_nok 'package omgnowai.yawai.;',           'package must not end with a dot';
g_ok 'package omgyawai.nowai.yawai.nowai;', 'package with dotted identifier';

g_nok 'option = lolwut;',                   'confused option should puke';
g_nok 'option wutlol;',                     'option w/o a value ';
g_ok 'option wutlol = "STRING LITERAL";',   'string literal option';
g_ok 'option wutlol = 0x4cb;',              'hex literal option';
g_ok 'option wutlol = 1;',                  'decimal literal option';
g_ok 'option wutlol = IDENT_CONSTANT;',     'ident constant';
g_ok 'option w = -1;', 'negative int constant';
g_ok 'option w = +1;', 'postive int constant';
g_ok 'option w = -0x42cb;', 'negative hex constant';
g_ok 'option w = +0x420;', 'positve hex constant';
g_ok 'option w = -2.24e2;', 'negative float constant';
g_ok 'option w = +2.34293845e98234979234;', 'positive float constant';
g_ok 'option w = -inf;', 'negative inf const';
g_ok 'option w = +inf;', 'positive inf const';

g_ok 'import "urmom.proto";', 'import w/ string lit';
g_nok 'import fart;', 'import w/ anything besides string lit';
g_ok "import 'fart.proto';", 'import w/ single quote string lit';

g_nok 'message{}', 'message w/o ident';
g_ok 'message a{required int32 a=3[a=B];}', 'message w/ field compact';
g_ok 'message a{};', 'allow message w/ semicolon on the end';

g_ok 'message x{required group Lol=4{};};', 'group w/ semi colon at the end';
g_nok 'message x{optional group lol=4{}}', 'group name must start with caps';

# g_nok 'message a{required int a=6;}', 'field w/ bad type';
g_nok 'message a{required a=4;}', 'field w/ no type';
g_nok 'message a{required int32 x 3 [a=B];}', 'field w/o equals sign for num';
g_nok 'message a{required int32=3[a=B];}', 'field w/o identifier';
g_ok 'message a{required int32 x=3[a=B,c="D",x="Y"];}', 'field w/ multiple opts';
g_ok 'message//nowai
a{}//yawai', 'message w/ wierd comments';
g_ok '/* some comment */', 'multiline comments';
g_ok 'message/*this
is
dumb*/plop/**/{}', 'hurty multiline comments';
g_ok '/* // omg */', 'single in a multi comment';
g_ok '// /* omg */', 'multi in a single comment';

g_ok 'option w = { x: B, y: C };', 'sub message option body';
g_ok 'option w = { x: "omg" y: "nowai"};', 'sub-message option body w/o comma separation';
g_ok 'option w = { sub { x: Y } };', 'sub message option body w/ block';
g_ok 'option w = { 
    ZZZ { 
        [foo.bar] { 
            s: "MY STRING"
        }
    }
};', 'sub message with block that also has a block';

ok PB::Grammar.parse('
    package com.niceword;
    option nice_thing = "face";
    import "allunicorns.proto";
    message not_ass {
        required double happy = 4;
        optional bool mild = 5;
        extensions 100 to 199, 500 to max;
        extensions 1 to max;

        option fancy = BLOOM;

        optional group Result = 8 {
            required string lolwut = 2 [default="yawai"];
        }

        enum Flower {
            BLOOM = 1;
            DIE = 5;
        }

        extend .lololol {}
        extend LOLOL.wut.nowai {
            required string yawai = 399 [my_opt = "\0xbc \n\n it happens"]    ;
        }

    }

    enum Trolololol {SHING=3;SHINE =4     ;}

    extend .not_ass {
        required int32 lolwut = 100;
        repeated group Ass = 101 {}
    }

    service things_that_do_stuff { rpc things (.stuff)returns (Trolololol);rpc wobble(lolwut)returns(noshing);}
'), "test a big complex mofo";

done-testing;
