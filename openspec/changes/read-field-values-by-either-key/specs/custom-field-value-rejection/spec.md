## ADDED Requirements

### Requirement: set_field_values reads its payload by String or Symbol keys

`set_field_values` SHALL read a plain Hash payload by a String key or its Symbol twin alike. This
holds for the group key, the slug, and the `id`, `group_number` and `values` of each entry. A plain
Hash with String keys, for example a `JSON.parse` result, MUST store the values of each entry and
validate its group number. The same payload with Symbol keys or with indifferent access gives the
same result. The method SHALL NOT change the keys of the Hash of the caller. Request parameters
SHALL store their values as before.

#### Scenario: A JSON.parse result stores its values

- **WHEN** a record holds a value and `set_field_values` gets a plain Hash with String keys whose
  entry holds values
- **THEN** the record holds the values of the entry, under the group number of the entry

#### Scenario: An entry with String keys validates its group number

- **WHEN** `set_field_values` gets a plain Hash with String keys whose entry holds an invalid group
  number
- **THEN** the call raises `ActiveRecord::RecordInvalid` with the group number error, and the record
  keeps its stored values

#### Scenario: The Hash of the caller keeps its keys

- **WHEN** `set_field_values` gets a plain Hash with String keys
- **THEN** after the call, the Hash holds the same keys and the same nested plain Hashes

#### Scenario: Request parameters store their values

- **WHEN** `set_field_values` gets unpermitted request parameters with an entry that holds values
- **THEN** the record holds the values of the entry
