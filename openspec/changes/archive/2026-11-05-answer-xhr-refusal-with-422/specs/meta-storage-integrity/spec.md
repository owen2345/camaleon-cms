## MODIFIED Requirements

### Requirement: Meta and option writers refuse a container that is not a set of fields

`set_metas` and `set_options` SHALL accept only a set of fields (a Hash, or request parameters) or nothing. A container that is present but not a set of fields, such as an array of pairs or a scalar, SHALL raise an argument error and store nothing. A `data_options` or `data_metas` value that is present but not a set of fields SHALL be refused the same way before the record's row is written, so no row is left behind it; a blank one SHALL be ignored. An admin save that passes such a container SHALL store none of it and SHALL NOT answer with a server error. It SHALL answer as a refused admin save answers (`custom-field-value-rejection`, the requirement "A refused admin save answers by the kind of the request").

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
