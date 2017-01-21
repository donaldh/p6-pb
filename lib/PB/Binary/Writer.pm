use v6;
use nqp;

#= Low level binary PB writer

unit module PB::Binary::Writer;

use PB::Binary::WireTypes;
use PB::Message;
use PB::RepeatClasses;


constant BIT_MASK_64_BITS = 1 +< 64 - 1;


#= Convert (field tag number, wire type) to a single field key
sub encode-field-key(int $field-tag, int $wire-type --> int) is pure is export {
    $field-tag +< 3 +| $wire-type
}


#= Encode a zigzag-encoded signed number
sub encode-zigzag(int $value --> int) is pure is export {
       ($value +< 1)  +& BIT_MASK_64_BITS
    +^ ($value +> 63) +& BIT_MASK_64_BITS;
}


#= Encode a value of an arbitrary field type
sub encode-value(Str $field-type, Mu $value --> Mu) is pure is export {
    given $field-type {
        when 'int32'|'uint32'|'fixed32'|'sfixed32'
            |'int64'|'uint64'|'fixed64'|'sfixed64'
            |'bytes'           { $value }
        when 'enum'            { +$value }
        when 'bool'            { +(?$value) }
        when 'sint32'|'sint64' { encode-zigzag($value) }
        when 'string'          { $value.encode }
        when 'float'|'double'  {
            die "XXXX: Don't know how to deal with floating point type '$_'";
        }
        default {
            write-message((my $sub-buf = buf8.new), (my $ = 0), $value);
            $sub-buf;
        }
    }
}


#= Write a varint into a buffer at a given offset, updating the offset
sub write-varint(buf8 $buffer, Int $offset is rw, int $param-value) is export {
    my $buf := nqp::decont($buffer);
    # Avoid infinite loop on negative values
    my $value = $param-value +& BIT_MASK_64_BITS;

    repeat while $value {
        my int $byte = $value +& 127;
        $value = $value +>   7;
        $byte  = $byte  +| 128 if $value;
        nqp::bindpos_i($buf, $offset++, $byte);
    }
}


#= Write a 32-bit (wire type 5) value into a buffer at a given offset, updating the offset
sub write-fixed32(buf8 $buffer, Int $offset is rw, int $value) is export {
    my $buf := nqp::decont($buffer);
    nqp::bindpos_i($buf, $offset++, $value       +& 255);
    nqp::bindpos_i($buf, $offset++, $value +>  8 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 16 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 24 +& 255);
}


#= Write a 32-bit (wire type 1) value into a buffer at a given offset, updating the offset
sub write-fixed64(buf8 $buffer, Int $offset is rw, int $value) is export {
    my $buf := nqp::decont($buffer);
    nqp::bindpos_i($buf, $offset++, $value       +& 255);
    nqp::bindpos_i($buf, $offset++, $value +>  8 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 16 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 24 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 32 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 40 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 48 +& 255);
    nqp::bindpos_i($buf, $offset++, $value +> 56 +& 255);
}


#= Write a blob8 into a buffer at a given offset, updating the offset
sub write-blob8(buf8 $buffer, Int $offset is rw, blob8 $blob8) is export {
    my $buf  := nqp::decont($buffer);
    my $blob := nqp::decont($blob8);
    my int $buflen  = nqp::elems($buf);
    my int $bloblen = nqp::elems($blob);

    nqp::setelems($buf, $offset + $bloblen)
           if $buflen < $offset + $bloblen;

    my int $s = 0;
    my int $d = $offset;
    while $s < $bloblen {
        nqp::bindpos_i($buf, $d, nqp::atpos_i($blob, $s));
        $s = $s + 1;
        $d = $d + 1;
    }

    $offset = $d;
}


#= Write a field tag, wire type, and value to a buffer at a given offset, updating the offset
sub write-pair(buf8 $buffer, Int $offset is rw, int $field-tag, int $wire-type,
               Any $value) is export {
    write-varint($buffer, $offset, encode-field-key($field-tag, $wire-type));

    given $wire-type {
        # Just plain values: varint, 32-bit, 64-bit
        when WireType::VARINT   { write-varint( $buffer, $offset, $value) }
        when WireType::FIXED_32 { write-fixed32($buffer, $offset, $value) }
        when WireType::FIXED_64 { write-fixed64($buffer, $offset, $value) }

        # Length-delimited
        when WireType::LENGTH_DELIMITED {
            write-varint($buffer, $offset, $value.elems);
            if $value ~~ blob8 {
                write-blob8($buffer, $offset, $value);
            }
            else {
                die "XXXX: Not handling length-delimited (wire type $_) for values of type {$value.WHAT} yet";
            }
        }

        # XXXX: Groups (unsupported, deprecated by Google)
        when WireType::START_GROUP | WireType::END_GROUP {
            die "XXXX: Can't handle groups (wire type $_)";
        }

        default { die "Invalid wire type $_" }
    }
}


#= Write an entire message to a buffer at a given offset, updating the offset
sub write-message(buf8 $buffer, Int $offset is rw, PB::Message $message) is export {
    my  @fields := $message.^ordered-fields;
    for @fields -> $field {
        my $name   = $field.pb_name;
        my $repeat = $field.pb_repeat;
        my $value  = $message."$name"();

        if !$value.defined {
            die "Cannot have an undefined value for required field '$name'"
                if $repeat ~~ RepeatClass::REQUIRED;
            next;
        }

        my $type      = $field.pb_type;
        my $field-tag = $field.pb_number;
        my $wire-type = %WIRE_TYPE{$type} // %WIRE_TYPE<DEFAULT>;

        if $repeat ~~ RepeatClass::REPEATED {
            if $field.pb_packed {
                # Don't write header of 0-entry packed fields
                next unless @$value;

                # Packed repeated: field-key, length, array of values
                my $field-key = encode-field-key($field-tag,
                                                 WireType::LENGTH_DELIMITED);
                write-varint($buffer, $offset, $field-key);

                given $wire-type {
                    when WireType::FIXED_32 {
                        write-varint($buffer, $offset, 4 * @$value);
                        for @$value {
                            my $encoded-value = encode-value($type, $_);
                            write-fixed32($buffer, $offset, $encoded-value);
                        }
                    }
                    when WireType::FIXED_64 {
                        write-varint($buffer, $offset, 8 * @$value);
                        for @$value {
                            my $encoded-value = encode-value($type, $_);
                            write-fixed64($buffer, $offset, $encoded-value);
                        }
                    }
                    when WireType::VARINT {
                        my $sub-buf    = buf8.new;
                        my $sub-offset = 0;
                        for @$value {
                            my $encoded-value = encode-value($type, $_);
                            write-varint($sub-buf, $sub-offset, $encoded-value);
                        }
                        write-varint($buffer, $offset, +@$sub-buf);
                        write-blob8($buffer, $offset, $sub-buf);
                    }
                    when WireType::LENGTH_DELIMITED {
                        die "Packing not allowed for repeated length delimited field '$name' (type '$type')";
                    }
                }
            }
            else {
                # Unpacked repeated: array of field-key/encoded-value pairs
                for @$value {
                    my $encoded-value = encode-value($type, $_);
                    write-pair($buffer, $offset, $field.pb_number,
                               $wire-type, $encoded-value);
                }
            }
        }
        else {
            # Required or optional: single field-key/encoded-value pair
            my $encoded-value = encode-value($type, $value);
            write-pair($buffer, $offset, $field.pb_number,
                       $wire-type, $encoded-value);
        }
    }
}
