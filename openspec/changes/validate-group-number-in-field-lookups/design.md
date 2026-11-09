# Design

## Terms

- A **value** is a custom-field value, a record of `CamaleonCms::CustomFieldsRelationship`.
- An author can add a repeatable field group to a post several times. The **group number** of a
  value is the index of the copy that the value belongs to: 0 for the first copy.
- A **valid** group number is nil, an Integer from 0 to 2147483647, or a String of 1 to 16 digits
  with such a number. Each other group number is **invalid**.
- The **group number error** is `ActiveRecord::RecordInvalid` with a message that names the field.
- The **readers** are `get_field_values` and `get_field_value`. `get_field_value` returns the first
  value of `get_field_values`, or its default.
- The **4-byte range** is -2147483648 to 2147483647, the range of the group number attribute.

## Context

See proposal.md, "Why". The change `refuse-invalid-field-group-number` added the validation of the
group number to the model of a value. It named `get_field_values` as a non-goal. So the writers
refused a group number that the readers still read.

## Goals / Non-Goals

**Goals:**

- A group number that the writers refuse reads no value. D2 names the exception.
- A reader gives the same stored values with or without a loaded `custom_field_values` association.
- `update_field_value` gives the caller an error for an invalid group number, as `set_field_value`
  does.

**Non-Goals:**

- A repair of stored values. A stored value with a negative group number stays.
- The same order of the values. The database gives them in the order of `term_order`, and a loaded
  association in the order of its rows.
- A key that is not a String or a Symbol. With a loaded association, a list of keys or an Integer
  key reads no value, as before. The database reads values for such a key.

## Decisions

**D1. A reader reads no value for an invalid group number, and it raises no error.** The reader
tests the group number as given, before the lookup. The integer cast cannot do the test, because it
changes an invalid number to a valid one. The readers get the group number from theme code, and
`get_field_value` already returns its default for each error.

- *Alternative: raise the group number error, as the writers do.* Rejected: `get_field_value`
  rescues each error, so only `get_field_values` raises. The two readers then differ for one number.
- *Alternative: leave the readers as they are.* Rejected: `'1abc'` then reads the values of
  group 1, a number that the writers refuse.

**D2. A negative Integer in the 4-byte range still reads its group.** A stored value can hold a
negative group number from an earlier release. The change `refuse-invalid-field-group-number` keeps
such a value writable (its D4). A reader that reads no value for the number hides the stored value
from the site. Only an Integer is the exception: a negative number as a String (`'-1'`) reads no
value.

**D3. A list (Array) reads each of its groups.** Without a loaded association, the database already
read the groups of a list. The list keeps that read, and a loaded association now gives it too.
Each item of the list gets the test of D1 and D2. One item that fails the test makes the list read
no value.

- *Alternative: read the groups of the items that pass.* Rejected: the caller then gets a part of
  the values, with no sign that an item was wrong.

**D4. A loaded association reads as the database reads.** The loaded branch compares the String of
a Symbol key with the slug of each row. It casts each group number with the type of the attribute.
So `:note`, `'1'` and `[0, 1]` read the same stored values on both branches.

An Integer outside the 4-byte range reads no value on both branches, because `where` finds no row
with such a number. Before, a loaded association read a stored value with that number (SQLite, a
`bigint` column). The maintainer chose the read of the database for that number.

- *Alternative: send a query also for a loaded association.* Rejected: a caller loads the
  association to send no query for each read. The query also reads no unsaved value of a loaded row.

**D5. One private lookup holds the rule.** `_cama_field_values_in_group` tests the group number and
reads the rows. It gives an Array for a loaded association, else a relation.

**D6. `update_field_value` raises the group number error before its lookup.** The method rescues
each error of the lookup and the write, and returns nil. So the validation runs outside the rescue.
The method refuses the same group numbers as `set_field_value`, with the exception of D7.

- *Alternative: return nil for an invalid group number.* Rejected: nil also says that the record
  holds no stored value with the number. The caller cannot tell a wrong number from an absent value.

**D7. `update_field_value` looks a negative Integer up with no validation.** The method changes no
group number, and the lookup finds only a value with that number. So a stored value from an earlier
release stays writable, as D4 of `refuse-invalid-field-group-number` says. The maintainer chose
this exception. A negative Integer outside the 4-byte range finds no value, and the method returns
nil.

**D8. The lookup of `update_field_value` reads the database, also with a loaded association.** A
loaded row can be stale: another instance replaced the stored row. A loaded row can also hold
unsaved changes of the caller, and an update of that row saves them too. So the method calls the
lookup of D5 with `loaded: false` and updates the stored row. It then puts the saved value in the
loaded row with the same id.

**D9. The message of the group number error holds the slug in UTF-8.** D6 put the validation
outside the rescue. For a slug in UTF-16, I18n then raised an encoding error in place of the group
number error. The model now converts the slug for the message. Ruby has no converter for some
encodings (UTF-7), and the message then keeps only the ASCII characters of the slug.

**D10. A loaded row gives its value through its `value` reader.** `Enumerable#pluck` reads the
attribute of each row, and it does not call a `value` method that the row defines. So
`get_field_values` calls `map(&:value)` on the Array of a loaded association. It calls
`pluck(:value)` only on a relation.

**D11. The delete of `set_field_value` uses the lookup of D5.** The method validates the group
number first, so the lookup gives a relation for each number that reaches it. The delete removes
the same stored values as before.

**D12. `get_fields_grouped` compares the String of a Symbol key.** Its query already read a Symbol
key as its String, so only the comparison with the slug of each row changed. Each group gives the
values under the key as given (`:note`), so the caller reads the Hash with the key that it passed.
The decorator methods `the_fields_grouped` and `the_field_grouped` read through this method.

- *Alternative: give the values under the String of the key.* Rejected: a caller that passes
  `:note` then finds no `:note` key in the Hash.

## Risks / Trade-offs

- [Theme code passes a group number that the cast misread, and depends on that read] → the read now
  gives no value. `docs/upgrading-to-2.9.5.md` names each such number. Each surveyed consumer reads
  the default group number 0 (`docs/ai/ecosystem.md`).
- [Code loads the association and passes a Symbol key, a String of digits or a list] → the read now
  gives the stored values. Before, it gave none. No surveyed consumer reads that way.
- [A stored value holds a group number outside the 4-byte range, see D4] → a loaded association now
  reads no value with it. The database read none before.
- [Code calls `update_field_value` with an invalid group number and expects nil] → the call now
  raises the group number error. `camaleon-ecommerce` is the only surveyed consumer that calls the
  method, with the default group number 0.
