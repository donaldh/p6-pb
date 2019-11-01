use v6;

#= Low level binary PB reader

unit module PB::Binary::Reader;

use PB::Binary::WireTypes;
use PB::Message;
use PB::RepeatClasses;

# SECURITY: Depends on the behavior of Blob.[] returning 0 for out of bounds
#           access (which e.g. makes read-varint self-terminate if it runs
#           off the end of the blob).  This must remain true even if the blob
#           is a subblob/subbuf.
#           XXXX: Tests to check this never regresses?


class X::PB::Binary::Invalid is Exception {
    has $.offset;
    has $.reason;

    method message {
        "Saw $.reason at offset $.offset; this doesn't look like a version 2 protocol buffer."
    }
}


class X::PB::Binary::WireType::Mismatch is Exception {
    has $.offset;
    has $.buffer-wiretype;
    has $.expected-wiretype;
    has $.message-type;
    has $.field;

    method message {
        "Saw wiretype $.buffer-wiretype for{ $.field.pb_packed ?? ' packed' !! '' } field $.field.pb_name (tag ID $.field.pb_number) of message type $.message-type at offset $.offset, but expected wiretype $.expected-wiretype instead.";
    }
}


#= Convert combined field key to (field tag number, wire type)
sub decode-field-key(int $key) is pure is export {
    $key +> 3, $key +& 7
}


#= Decode a zigzag-encoded signed number
sub decode-zigzag(int $zigzag --> int) is pure is export {
    ($zigzag +> 1) +^ -($zigzag +& 1)
}


#= Decode a value of an arbitrary field type
multi sub decode-value(Str $field-type, Mu $value --> Mu) is pure is export {
    given $field-type {
        when 'int32'|'uint32'|'fixed32'|'sfixed32'
            |'int64'|'uint64'|'fixed64'|'sfixed64'
            |'bytes'           { $value }
        when 'enum'            { $value }  # XXXX: Decode to real Enum?
        when 'bool'            { ?$value }
        when 'sint32'|'sint64' { decode-zigzag($value) }
        when 'string'          { $value.decode }
        when 'float'|'double'  {
            die "XXXX: Don't know how to deal with floating point type '$_'";
        }
        default {
            # XXXX: How to look up message type from string type name?
            my $message-type = PB::Message;  # message-type($field-type);
            read-message($message-type, $value, (my $ = 0))
        }
    }
}

multi sub decode-value(PB::Message $message-type, Mu $value --> Mu) is pure is export {
    read-message($message-type, $value, (my $ = 0))
}

#= Read a varint from a buffer at a given offset, updating the offset
sub read-varint(blob8 $buffer, Int $offset is rw --> uint) is export {
    my Int $value = 0;
    my int $shift = 0;
    my int $high-bit;

    repeat while $high-bit {
        my $byte  = $buffer[$offset++];
        $high-bit = $byte +& 128;
        $value   += $byte +& 127 +< $shift;
        $shift    = $shift + 7;
    }

    $value;
}


#= Read a 32-bit (wire type 5) value from a buffer at a given offset, updating the offset
sub read-fixed32(blob8 $buffer, Int $offset is rw --> uint32) is export {
      $buffer[$offset++]
    + $buffer[$offset++] +<  8
    + $buffer[$offset++] +< 16
    + $buffer[$offset++] +< 24
}


#= Read a 64-bit (wire type 1) value from a buffer at a given offset, updating the offset
sub read-fixed64(blob8 $buffer, Int $offset is rw --> uint64) is export {
      $buffer[$offset++]
    + $buffer[$offset++] +<  8
    + $buffer[$offset++] +< 16
    + $buffer[$offset++] +< 24
    + $buffer[$offset++] +< 32
    + $buffer[$offset++] +< 40
    + $buffer[$offset++] +< 48
    + $buffer[$offset++] +< 56
}


#= Read a blob8 from a buffer at a given offset with a given length, updating the offset
sub read-blob8(blob8 $buffer, Int $offset is rw, Int $length --> blob8) is export {
    my $blob := $buffer.subbuf($offset, $length);
    $offset  += min($length, $blob.elems);
    $blob;
}


#= Read a kv pair from a buffer at a given offset, updating the offset
sub read-pair(blob8 $buffer, Int $offset is rw) is export {
    my $orig-offset = $offset;
    my ($field-tag, $wire-type)
        = decode-field-key(read-varint($buffer, $offset));

    my $value = do given $wire-type {
        # Just plain values: varint, 64-bit, 32-bit
        when WireType::VARINT   { read-varint( $buffer, $offset) }
        when WireType::FIXED_64 { read-fixed64($buffer, $offset) }
        when WireType::FIXED_32 { read-fixed32($buffer, $offset) }

        # Length-delimited
        when WireType::LENGTH_DELIMITED {
            my $length = read-varint($buffer, $offset);
            read-blob8($buffer, $offset, $length);
        }

        # XXXX: Groups (unsupported, deprecated by Google)
        when WireType::START_GROUP | WireType::END_GROUP {
            die "XXXX: Can't handle groups (wire type $_)"
        }

        default  {
            fail X::PB::Binary::Invalid.new(:offset($orig-offset),
                :reason("wire type $_ for field tag $field-tag"))
        }
    }

    ($field-tag, $wire-type, $value);
}


#= Read an entire message from a buffer at a given offset with an optional maximum length, updating the offset
sub read-message(PB::Message $message-type, blob8 $buffer, Int $offset is rw,
                 Int $length?) is export {
    # For security, if $length is set, decode a sub-buf instead
    if $length.defined {
        my $sub-buf := $buffer.subbuf($offset, $length);
        $offset += @$sub-buf;
        return read-message($message-type, $sub-buf, (my $ = 0));
    }

    #say "Decoding {$message-type.^name}";
    my $message = $message-type.new;
    my %field  := $message-type.^fields-by-tag;
    while $offset < @$buffer {
        my $orig-offset = $offset;
        my ($field-tag, $wire-type, $value) = read-pair($buffer, $offset);
        my $field = %field{$field-tag};

        if !$field.defined {
            $message.unknown-fields.push({ :$field-tag, :$wire-type, :$value });
            next;
        }

        my $pb_type = $field.pb_type;
        my $expected-wiretype  = %WIRE_TYPE{$pb_type}
                              // %WIRE_TYPE<DEFAULT>;

        my $repeated = $field.pb_repeat ~~ RepeatClass::REPEATED;
        my $packed = $repeated && $wire-type !~~ WireType::LENGTH_DELIMITED;

        fail X::PB::Binary::WireType::Mismatch.new(
            :offset($orig-offset), :$field, :$message-type,
            :buffer-wiretype($wire-type), :$expected-wiretype)
            unless $packed || $wire-type ~~ $expected-wiretype;

        my $name = $field.pb_name;
        my $attr = $message."$name"();

        # XXXX: Check for type mismatches?
        # XXXX: Check for buffer overruns from bad length?
        if $packed {
            fail X::PB::Binary::Invalid.new(:$offset,
                                            :reason("packed data for field with expected wiretype $expected-wiretype"))
                unless $expected-wiretype ~~ WireType::VARINT
                                           | WireType::FIXED_32
                                           | WireType::FIXED_64;

            my @array := $message."$name"();
            my $sub-offset = 0;
            my $sub-length = $value.elems;

            # Seriously needs optimization
            while $sub-offset < $sub-length {
                my $raw-value = do given $expected-wiretype {
                    when WireType::VARINT   { read-varint( $value, $sub-offset) }
                    when WireType::FIXED_64 { read-fixed64($value, $sub-offset) }
                    when WireType::FIXED_32 { read-fixed32($value, $sub-offset) }
                    # No default; other cases blocked by guard above
                }

                @array.push(decode-value($pb_type, $raw-value));
            }
        }
        elsif $repeated {
            my $type = $message.resolve($pb_type);
            $message."$name"().push(decode-value($type, $value));
        }
        else {
            $message."$name"() = decode-value($pb_type, $value);
        }
    }

    $message;
}
