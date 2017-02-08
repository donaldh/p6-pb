use v6;

use Test;
use PB::Binary::Writer;


#= Root of all test data directories
constant $DATA_ROOT = $*PROGRAM-NAME.path.dirname ~ '/data';

#= Directory containing .proto files from official protobuf docs
constant $PROTO_DIR = "$DATA_ROOT/google-docs";


{
    use PB::Model::Generator "$PROTO_DIR/test1.proto";
    BEGIN {
        pass 'parsed test1.proto';
        nok ::('Test1') ~~ Failure, 'generated a Test1 class';
        is Test1.^perl, q:to/TEST1/, 'Test1.^perl produces correct output';
            class Test1 is PB::Message {
                has Int $.a is pb_type("int32") is pb_name("a") is pb_number(1) is pb_repeat(REQUIRED);
            }
            TEST1

        my $test1  = Test1.new(:a(150));
        is $test1.a, 150, 'test1.a has correct value';

        my $buf1  := buf8.new();
        my $offset = 0;
        write-message($buf1, $offset, $test1);
        my $good1 := buf8.new(0x08, 0x96, 0x01);
        is-deeply $buf1, $good1, 'wrote sample test1 buffer correctly';
    }
}


{
    use PB::Model::Generator "$PROTO_DIR/test2.proto";
    BEGIN {
        pass 'parsed test2.proto';
        nok ::('Test2') ~~ Failure, 'generated a Test2 class';
        is Test2.^perl, q:to/TEST2/, 'Test2.^perl produces correct output';
            class Test2 is PB::Message {
                has Str $.b is pb_type("string") is pb_name("b") is pb_number(2) is pb_repeat(REQUIRED);
            }
            TEST2

        my $test2  = Test2.new(:b('testing'));
        is $test2.b, 'testing', 'test2.b has correct value';

        my $buf2  := buf8.new();
        my $offset = 0;
        write-message($buf2, $offset, $test2);
        my $good2 := buf8.new(0x12, 0x07, 0x74, 0x65, 0x73,
                              0x74, 0x69, 0x6e, 0x67);
        is-deeply $buf2, $good2, 'wrote sample test2 buffer correctly';
    }
}


{
    use PB::Model::Generator "$PROTO_DIR/test1.proto";
    use PB::Model::Generator "$PROTO_DIR/test3.proto";
    BEGIN {
        pass 'parsed test1.proto and test3.proto';
        nok ::('Test1') ~~ Failure, 'generated a Test1 class';
        nok ::('Test3') ~~ Failure, 'generated a Test3 class';
        is Test1.^perl, q:to/TEST1/, 'Test1.^perl produces correct output';
            class Test1 is PB::Message {
                has Int $.a is pb_type("int32") is pb_name("a") is pb_number(1) is pb_repeat(REQUIRED);
            }
            TEST1
        is Test3.^perl, q:to/TEST3/, 'Test3.^perl produces correct output';
            class Test3 is PB::Message {
                has Any $.c is pb_type("Test1") is pb_name("c") is pb_number(3) is pb_repeat(REQUIRED);
            }
            TEST3

        my $test1  = Test1.new(:a(150));
        is $test1.a, 150, 'test1.a has correct value';
        my $test3  = Test3.new(:c($test1));
        is $test3.c, $test1, 'test3.c has correct value';

        my $buf3  := buf8.new();
        my $offset = 0;
        write-message($buf3, $offset, $test3);
        my $good3 := buf8.new(0x1a, 0x03, 0x08, 0x96, 0x01);
        is-deeply $buf3, $good3, 'wrote sample test3 buffer correctly';
    }
}


{
    use PB::Model::Generator "$PROTO_DIR/test4.proto";
    BEGIN {
        pass 'parsed test4.proto';
        nok ::('Test4') ~~ Failure, 'generated a Test4 class';
        is Test4.^perl, q:to/TEST4/, 'Test4.^perl produces correct output';
            class Test4 is PB::Message {
                has Int @.d is pb_type("int32") is pb_name("d") is pb_number(4) is pb_repeat(REPEATED) is pb_packed;
            }
            TEST4

        my $test4  = Test4.new(:d(3, 270, 86942));
        is-deeply $test4.d, [3, 270, 86942], 'test4.d has correct value';

        my $buf4  := buf8.new();
        my $offset = 0;
        write-message($buf4, $offset, $test4);
        my $good4 := buf8.new(0x22, 0x06, 0x03, 0x8E, 0x02, 0x9E, 0xA7, 0x05);
        is-deeply $buf4, $good4, 'wrote sample test4 buffer correctly';
    }
}


# A big one -- the proto defining the official data model for protos
{
    # use PB::Model::Generator "$DATA_ROOT/protobuf-read-only/src/google/protobuf/descriptor.proto";
    BEGIN {
        # pass 'parsed protobuf/descriptor.proto';
        # XXXX: Check all expected classes were generated properly
    }
}


# Tell prove that we've completed testing normally
done;
