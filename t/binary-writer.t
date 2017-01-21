use v6;

use Test;
use PB::Binary::WireTypes;
use PB::Binary::Writer;


# ENCODING TESTS

# Tests for encode-field-key()
for flat (0, 1, 2, 3, 200, 60_000, 20_000_000) X ^8 -> $tag, $type {
    is encode-field-key($tag, $type), $tag +< 3 + $type,
       "encode-field-key($tag, $type) encodes field key properly";
}

# Tests for encode-zigzag()
my @zigzag-pairs = <
    0     0
    1    -1
    2     1
    3    -2
    4     2
    5    -3
    6     3
    7    -4
    8     4
    4294967294     2147483647
    4294967295    -2147483648
>;

for @zigzag-pairs.list -> $coded, $decoded {
    is encode-zigzag(+$decoded), +$coded, "encode-zigzag($decoded) works";
}


# BUFFER-WRITING TESTS

# Trivial buffer (first example in Google's encoding docs)
my buf8 $buffer := buf8.new();
my $offset       = 0;
write-varint($buffer, $offset, 8);
is $buffer[0], 0x08, '1-byte varint at offset 0 written correctly';
is $offset, 1, '... and offset was updated correctly';

write-varint($buffer, $offset, 150);
is $buffer[1], 0x96, 'First  byte of 2-byte varint at offset 1 written correctly';
is $buffer[2], 0x01, 'Second byte of 2-byte varint at offset 1 written correctly';
is $offset, 3, '... and offset was updated correctly';

$buffer := buf8.new();
$offset  = 0;
write-pair($buffer, $offset, 1, WireType::VARINT, 150);
my $trivial := buf8.new(0x08, 0x96, 0x01);
is-deeply $buffer, $trivial, 'Wrote trivial buffer correctly';
is $offset, 3, '... and offset was updated correctly';

# Buffer containing fixed size fields
$buffer := buf8.new();
$offset  = 1;
write-fixed32($buffer, $offset, 0x12345678);
is $buffer[1], 0x78, 'First  byte of fixed32 at offset 1 written correctly';
is $buffer[2], 0x56, 'Second byte of fixed32 at offset 1 written correctly';
is $buffer[3], 0x34, 'Third  byte of fixed32 at offset 1 written correctly';
is $buffer[4], 0x12, 'Fourth byte of fixed32 at offset 1 written correctly';
is $offset, 5, '... and offset was updated correctly';

$offset = 6;
write-fixed64($buffer, $offset, 0x12345678BEEFCAFE);
is $buffer[ 6], 0xFE, 'First   byte of fixed64 at offset 6 written correctly';
is $buffer[ 7], 0xCA, 'Second  byte of fixed64 at offset 6 written correctly';
is $buffer[ 8], 0xEF, 'Third   byte of fixed64 at offset 6 written correctly';
is $buffer[ 9], 0xBE, 'Fourth  byte of fixed64 at offset 6 written correctly';
is $buffer[10], 0x78, 'Fifth   byte of fixed64 at offset 6 written correctly';
is $buffer[11], 0x56, 'Sixth   byte of fixed64 at offset 6 written correctly';
is $buffer[12], 0x34, 'Seventh byte of fixed64 at offset 6 written correctly';
is $buffer[13], 0x12, 'Eighth  byte of fixed64 at offset 6 written correctly';
is $offset, 14, '... and offset was updated correctly';

$buffer := buf8.new();
$offset  = 0;
write-pair($buffer, $offset, 1, WireType::FIXED_32, 0x12345678);
write-pair($buffer, $offset, 2, WireType::FIXED_64, 0x12345678BEEFCAFE);
my $fixed-fields := buf8.new(0x0D, 0x78, 0x56, 0x34, 0x12,
                             0x11, 0xFE, 0xCA, 0xEF, 0xBE,
                                   0x78, 0x56, 0x34, 0x12);
is-deeply $buffer, $fixed-fields, 'Wrote fixed fields buffer correctly';
is $offset, 14, '... and offset was updated correctly';


# Buffer containing simple length-delimited values: string and bytes
$buffer := buf8.new();
$offset  = 1;
write-blob8($buffer, $offset, blob8.new(0..255));
is-deeply $buffer.subbuf(1), buf8.new(0..255), 'Wrote bytes 0..255 correctly';
is $offset, 257, '... and offset was updated correctly';

$buffer := buf8.new();
$offset  = 1;
write-blob8($buffer, $offset, 'testing'.encode);
is $buffer.subbuf(1).decode, 'testing', "Wrote string 'testing' correctly";
is $offset, 8, '... and offset was updated correctly';

$buffer := buf8.new();
$offset  = 0;
write-pair($buffer, $offset, 2, WireType::LENGTH_DELIMITED, '«①🚀»'.encode);
is $buffer[0], 18, 'Wrote field key for length delimited field correctly';
is $buffer[1], 11, 'Wrote field length correctly';
is $buffer.subbuf(2).decode, '«①🚀»', "Wrote utf-8 string correctly";
is $offset, 13, '... and offset was updated correctly';


# Tell prove that we've completed testing normally
done;
