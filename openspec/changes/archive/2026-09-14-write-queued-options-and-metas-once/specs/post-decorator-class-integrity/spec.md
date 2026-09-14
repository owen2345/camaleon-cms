## MODIFIED Requirements

### Requirement: The decorator class option names a post decorator

A write that sets or changes a post type's `cama_post_decorator_class` option SHALL be accepted only
when the new value is blank or names a class that is a subclass of `CamaleonCms::PostDecorator`. Any
other value, an unknown class name, a name that cannot be loaded or a class outside the decorator
hierarchy, SHALL be refused at save with an error naming the option, and the value when it is a
class name, and the post type's stored options SHALL be left exactly as they were. The check SHALL
apply to every writer, administrators included, through every option writer and whatever form the
options are passed in. A write that leaves a stored value unchanged SHALL NOT be refused for it.

#### Scenario: A decorator subclass

- **WHEN** the option is set to the name of a `CamaleonCms::PostDecorator` subclass
- **THEN** it SHALL be stored and posts of the type SHALL decorate with that class

#### Scenario: A class outside the decorator hierarchy

- **WHEN** the option is set to the name of a class that is not a `CamaleonCms::PostDecorator`
  subclass, whoever writes it and however it is written
- **THEN** the save SHALL fail with an error naming the option and the value, and the previously
  stored options SHALL remain

#### Scenario: An unknown class name

- **WHEN** the option is set to a name that resolves to no class
- **THEN** the save SHALL fail the same way

#### Scenario: A name that cannot be loaded

- **WHEN** the option is set to a name that fails to load, such as a path through a constant that is
  not a module or a decorator whose file raises while loading
- **THEN** the save SHALL fail the same way, not with a server error

#### Scenario: Options passed in any form

- **WHEN** the option is written through `set_meta` as `ActionController::Parameters`, as a JSON
  string, or as a Hash carrying both the String and the Symbol form of its key
- **THEN** the value that would be stored SHALL be the one checked

#### Scenario: Clearing the option

- **WHEN** the option is set to a blank value
- **THEN** it SHALL be accepted and posts of the type SHALL decorate with the default decorator

#### Scenario: Other options are unaffected

- **WHEN** a post type's other options are written without the decorator option
- **THEN** they SHALL be stored as before

#### Scenario: A stored value the check would refuse

- **WHEN** a post type holds such a value and its other options are written, deleted or saved with
  the post type
- **THEN** those writes SHALL succeed and the stored value SHALL remain, while changing it to another
  value the check refuses SHALL still be refused

#### Scenario: A value passed to a save

- **WHEN** a post type is created or updated with the option set to a value the check refuses, in
  `data_options` or in the `_default` meta of `data_metas`
- **THEN** the save SHALL fail as a validation carrying the error, before anything is written, also
  inside an enclosing transaction, and `create!` and `update!` SHALL raise

#### Scenario: A refused write on a record with its metas loaded

- **WHEN** a write on a record whose metas association is loaded is refused and the record then
  writes another option
- **THEN** the options it wrote before the refusal SHALL remain stored
