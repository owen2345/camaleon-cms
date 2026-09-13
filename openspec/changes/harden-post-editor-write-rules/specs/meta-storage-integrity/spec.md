## ADDED Requirements

### Requirement: An options row that is not an object reads as empty

When a record's stored options meta (`_default`, or another options meta key) holds a value that is not a JSON object, reading the options or an option SHALL return the empty set or the caller's default, and writing an option SHALL start from an empty set, so no reader or writer raises on the row. The stored row SHALL be left as it is until an option is written to it.

#### Scenario: Options are read from a string row

- **WHEN** a post's `_default` meta holds the string `corrupt` and its option `status_default` is read with a default
- **THEN** the default is returned and nothing raises

#### Scenario: An option is written over a string row

- **WHEN** a post's `_default` meta holds the string `corrupt` and `status_default` is set
- **THEN** the options hold `status_default` and nothing raises

#### Scenario: Pages of a post with a string row render

- **WHEN** a post's `_default` meta holds a string and its admin edit page, its public page and its trash action are requested
- **THEN** each responds as for a post with no options

### Requirement: Meta and option writers refuse a container that is not a set of fields

`set_metas` and `set_options` SHALL accept only a set of fields (a Hash, or request parameters) or nothing. A container that is present but not a set of fields, such as an array of pairs or a scalar, SHALL raise an argument error and store nothing. An admin save that passes such a container from the request SHALL answer with an error message on the submitted form's page, not a server error, and SHALL store none of it.

#### Scenario: An array of pairs is refused by the writer

- **WHEN** `set_metas` is called with `[["k", "v"]]`
- **THEN** it raises and no meta row is written

#### Scenario: A category save with an array container answers with a message

- **WHEN** an administrator saves a category with `meta[]=x`
- **THEN** the response redirects back with an error message and no option is stored

#### Scenario: A site settings save with an array of pairs stores nothing

- **WHEN** an administrator saves the site settings with a JSON `metas` array of pairs
- **THEN** the response carries an error message and none of the pairs is stored
