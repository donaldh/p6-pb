use v6;

use Test;
use PB::Binary::WireTypes;


# WIRE TYPE ENUMERATION TESTS

# Make sure someone doesn't accidentally renumber these
is +WireType::VARINT,           0, "Wire type VARINT has correct value 0";
is +WireType::FIXED_64,         1, "Wire type FIXED_64 has correct value 1";
is +WireType::LENGTH_DELIMITED, 2, "Wire type LENGTH_DELIMITED has correct value 2";
is +WireType::START_GROUP,      3, "Wire type START_GROUP has correct value 3";
is +WireType::END_GROUP,        4, "Wire type END_GROUP has correct value 4";
is +WireType::FIXED_32,         5, "Wire type FIXED_32 has correct value 5";


# Tell prove that we've completed testing normally
done-testing;
