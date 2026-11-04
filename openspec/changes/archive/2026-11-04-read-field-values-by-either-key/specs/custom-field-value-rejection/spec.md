## ADDED Requirements

### Requirement: set_field_values reads its payload by String or Symbol keys

`set_field_values` SHALL read a plain Hash payload by a String key or its Symbol twin alike. This
holds for the group key, the slug, and the `id`, `group_number` and `values` of each entry. A plain
Hash with String keys, for example a `JSON.parse` result, MUST store the values of each entry and
validate its group number. The same payload with Symbol keys or with indifferent access gives the
same result. The method SHALL NOT change the keys of the Hash of the caller. Request parameters
SHALL store their values as before. A plain Hash with a String key and its Symbol twin at one level
MUST raise `ArgumentError` before the delete. The record then keeps its stored values.

#### Scenario: A JSON.parse result stores its values

- **WHEN** a record holds a value and `set_field_values` gets a plain Hash with String keys whose
  entry holds values
- **THEN** the record holds the values of the entry, under the group number of the entry

#### Scenario: An entry with String keys validates its group number

- **WHEN** `set_field_values` gets a plain Hash with String keys whose entry holds an invalid group
  number
- **THEN** the call raises `ActiveRecord::RecordInvalid` with the group number error, and the record
  keeps its stored values

#### Scenario: A String key and its Symbol twin are refused

- **WHEN** `set_field_values` gets a plain Hash that holds `:note` and `'note'` at one level
- **THEN** the call raises `ArgumentError`, and the record keeps its stored values

#### Scenario: The Hash of the caller keeps its keys

- **WHEN** `set_field_values` gets a plain Hash with String keys
- **THEN** after the call, the Hash holds the same keys and the same nested plain Hashes

#### Scenario: Request parameters store their values

- **WHEN** `set_field_values` gets unpermitted request parameters with an entry that holds values
- **THEN** the record holds the values of the entry

### Requirement: set_field_value reads its args by String or Symbol keys

`set_field_value` SHALL read its args by a String key or its Symbol twin alike. This holds for
`field_id`, `order`, `group_number` and `clear`. Args with a String key and its Symbol twin MUST raise
`ArgumentError` before the delete. The record then keeps its stored values.

#### Scenario: A group number with a String key

- **WHEN** a record holds a value in group 0 and `set_field_value` gets `{ 'group_number' => 1 }`
- **THEN** the record holds the new value in group 1, and group 0 keeps its value

#### Scenario: The clear option with a String key

- **WHEN** `set_field_value` gets `{ 'clear' => false }`
- **THEN** the record keeps its stored values of the field and adds the new value

#### Scenario: A String key and its Symbol twin in the args are refused

- **WHEN** `set_field_value` gets `{ clear: true, 'clear' => false }`
- **THEN** the call raises `ArgumentError`, and the record keeps its stored values
