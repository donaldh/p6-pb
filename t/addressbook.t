use Test;

use PB::Model::Generator 't/data/addressbook.proto';
use PB::Binary::Writer;
use PB::Binary::Reader;

my $ab = AddressBook.new(
        people => [
            Person.new(name => 'Mary Sue',
                phones => PhoneNumber.new(
                number => '01010101010')
                #type => Person.PhoneType.MOBILE)
            ),
            Person.new(name => 'John Doe',
                phones => PhoneNumber.new(
                number => '00000000000')
                #type => Person.PhoneType.MOBILE)
            )
        ]);

my $buf := buf8.new;
write-message($buf, (my $ = 0), $ab);

my $parsed = read-message(AddressBook, $buf, (my $ = 0));

is-deeply($parsed, $ab, 'Round-trip the AddressBook message');

done-testing
