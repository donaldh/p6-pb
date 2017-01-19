use v6;

#= Low level binary PB wire types

unit module PB::Binary::WireTypes;


#= Binary wire types
enum WireType is export <
    VARINT
    FIXED_64
    LENGTH_DELIMITED
    START_GROUP
    END_GROUP
    FIXED_32
    >;


#= Field type to wire type mapping
# hash() to work around https://rt.perl.org/Public/Bug/Display.html?id=111944
constant %WIRE_TYPE is export = hash(
    ($_ => VARINT for < bool enum int32 sint32 uint32 int64 sint64 uint64 >),
    ($_ => FIXED_32 for < fixed32 sfixed32 >),
    ($_ => FIXED_64 for < fixed64 sfixed64 >),
    ($_ => LENGTH_DELIMITED for < string bytes DEFAULT >),
);
