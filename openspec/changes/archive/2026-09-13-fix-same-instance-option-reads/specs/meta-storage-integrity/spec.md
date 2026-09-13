## ADDED Requirements

### Requirement: Option reads on the writing instance find either key type

On the instance that wrote a record's options, `options` and `get_option` SHALL find an option by a String
key or its Symbol twin, as a reloaded record does. This SHALL hold whatever the instance holds for the
options: a hash the option writers updated, or a plain Hash or request parameters a caller passed to
`set_meta`. `get_meta` on that instance SHALL still return the value the caller passed, with the caller's
own keys.

#### Scenario: Options a caller passed to set_meta as a plain Hash

- **WHEN** a post type's options are written with `set_meta` as a plain Hash holding `color` under a String
  key and `size` under a Symbol key
- **THEN** on the same instance, `options` and `get_option` read `color` by its Symbol key and `size` by
  its String key
- **AND** a reloaded post type reads the same values
- **AND** `get_meta` on the same instance returns the hash the caller passed, with its own keys

#### Scenario: Options a caller passed to set_meta as request parameters

- **WHEN** a post type's options are written with `set_meta` as request parameters holding `color`
- **THEN** on the same instance, `options` and `get_option` read `color` by its String key and by its
  Symbol key

### Requirement: Options that are nil or empty read and write as none

When the options a record holds are nil or an empty string, `options` SHALL return empty options,
`get_option` SHALL return the caller's default, and the option writers SHALL start from empty options, on
the writing instance and after a reload. This SHALL hold whether an earlier `get_meta` read without a
default left nil for a record with no stored options, or `set_meta` wrote nil or an empty string. Neither
a read nor a write SHALL raise.

#### Scenario: A get_meta read without a default on a record with no options

- **WHEN** a post with no stored options has its options read with `get_meta` without a default, and then
  its options are read and an option is set on the same instance
- **THEN** `options` is empty and `get_option` returns the caller's default
- **AND** the same instance and a reloaded post read the option that was set

#### Scenario: Options written as nil or as an empty string

- **WHEN** a post's options are written with `set_meta` as nil, or as an empty string
- **THEN** `options` is empty and `get_option` returns the caller's default, on the same instance and on a
  reloaded post
- **AND** an option set on the reloaded post is read by a post loaded afterwards
