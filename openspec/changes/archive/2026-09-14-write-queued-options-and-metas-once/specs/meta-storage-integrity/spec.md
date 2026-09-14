## MODIFIED Requirements

### Requirement: Options and metas given to a save are written once

Options and metas assigned through `data_options` and `data_metas` SHALL be written by the first save
of the record that completes, and a later save of the same instance SHALL NOT write them again; once
written, both accessors SHALL read `nil`. The metas SHALL be written before the options, so a
`_default` meta given in `data_metas` merges with `data_options` instead of replacing them. When the
transaction that wrote them is rolled back, they SHALL be queued again for the record's next save,
keeping any value queued since; a rollback of a later transaction of the instance SHALL leave them
written. A post type SHALL fill its default options in under the options set on the record before
its first save and under the ones given.

#### Scenario: A post type updated after an option write

- **WHEN** a post type created with `has_category` in `data_options` sets `has_category` to `false` and is
  then renamed
- **THEN** the same instance and a freshly loaded post type read `has_category` as `false`

#### Scenario: A post updated after new option and meta writes

- **WHEN** a post created or updated with `data_options` and `data_metas` writes new values for those keys
  and is then updated again
- **THEN** the same instance and a freshly loaded post read the new values

#### Scenario: A post type created with data_metas

- **WHEN** a post type is created with `data_metas`
- **THEN** a freshly loaded post type reads those metas

#### Scenario: A post type created with a `_default` meta and options

- **WHEN** a post type is created with `has_category` in `data_options` and a `_default` meta holding
  `has_tags`
- **THEN** a freshly loaded post type reads both, its remaining defaults, and has its default category

#### Scenario: An option set before a post type's first save

- **WHEN** an unsaved post type given `data_options` sets one of the default options and is saved
- **THEN** a freshly loaded post type reads the option it set, the options given and the remaining
  defaults, from one options row

#### Scenario: A meta built before a post type's first save

- **WHEN** an unsaved post type given a meta in `data_metas` sets the same meta and is saved
- **THEN** its loaded metas and a freshly loaded post type both read the value given in `data_metas`

#### Scenario: A save rolled back after writing them

- **WHEN** a post type's creation raises in a later callback, or a post's update given `data_options`
  and `data_metas` is rolled back by an enclosing transaction, and the instance is saved again
- **THEN** a freshly loaded record reads the queued values, stored once

#### Scenario: A later save of the instance rolled back

- **WHEN** a post created with `data_options` sets an option, has a later update rolled back and is
  updated again
- **THEN** a freshly loaded post reads the option set after the creation

### Requirement: Meta and option writers refuse a container that is not a set of fields

`set_metas` and `set_options` SHALL accept only a set of fields (a Hash, or request parameters) or nothing. A container that is present but not a set of fields, such as an array of pairs or a scalar, SHALL raise an argument error and store nothing. A `data_options` or `data_metas` value that is present but not a set of fields SHALL be refused the same way before the record's row is written, so no row is left behind it; a blank one SHALL be ignored. An admin save that passes such a container from the request SHALL answer with an error message on the submitted form's page, not a server error, and SHALL store none of it.

#### Scenario: An array of pairs is refused by the writer

- **WHEN** `set_metas` is called with `[["k", "v"]]`
- **THEN** it raises and no meta row is written

#### Scenario: A queued container that is not a set of fields

- **WHEN** a post type is saved with a JSON string in `data_options`, or a post with an array of pairs in
  `data_metas`, inside an enclosing transaction
- **THEN** the save raises the argument error and no row is stored

#### Scenario: A category save with an array container answers with a message

- **WHEN** an administrator saves a category with `meta[]=x`
- **THEN** the response redirects back with an error message and no option is stored

#### Scenario: A site settings save with an array of pairs stores nothing

- **WHEN** an administrator saves the site settings with a JSON `metas` array of pairs
- **THEN** the response carries an error message and none of the pairs is stored
