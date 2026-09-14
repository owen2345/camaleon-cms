# post-decorator-class-integrity Specification

## Purpose
A post type's decorator class option is loaded as code, so it may name only a post decorator: a
write that sets any other value is refused at save, a stored value that is not one is ignored at
render in favour of the default decorator, and such values are reported by the security scan.

## Requirements

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

### Requirement: A refusal from a save hook surfaces in the admin panel

When a hook run after an admin post type save writes a value the check refuses, the admin panel
SHALL answer with a redirect carrying the refusal as a flash error rather than a server error. The
post type's own attributes, saved before the hook ran, remain saved. The flash SHALL quote the value
only when it is a class name, cut short, and SHALL NOT echo any other value. A refusal that comes
while the admin panel serves a GET or HEAD request is no submitted save and SHALL be raised, not
redirected.

#### Scenario: A hook stores a rejected value

- **WHEN** a hook run after an admin post type save writes a non-decorator class name into the
  option
- **THEN** the response SHALL redirect with the error in the flash, the option SHALL stay unset,
  and posts of the type SHALL decorate with the default decorator

#### Scenario: A hook stores markup or an overlong name

- **WHEN** a hook run after an admin post type save writes markup, or a class name longer than the
  session cookie can carry, into the option
- **THEN** the response SHALL redirect with the error in the flash, the markup SHALL NOT appear in the
  flash or on the next page, and no server error SHALL occur

#### Scenario: Saving a post type that holds a stored value the check would refuse

- **WHEN** an administrator saves the settings of such a post type
- **THEN** the save SHALL succeed and the stored value SHALL remain

#### Scenario: A refusal while serving a page

- **WHEN** a value the check refuses is written while the admin panel serves a GET or HEAD request,
  such as by a hook run before every admin page
- **THEN** the refusal SHALL be raised rather than redirected, so no page redirects to another that
  refuses again

### Requirement: A post resolves its decorator safely

A post SHALL decorate with the class named by its post type's option when that class is a
`CamaleonCms::PostDecorator` subclass, and with `CamaleonCms::PostDecorator` otherwise: a blank
option, a post without a post type, a post type whose options row is not a JSON object (which reads as
no options), or a stored value the check would refuse (written before the check, left by a removed
plugin, or imported). A stored value that is ignored SHALL be logged as a warning naming the post type
and the value, once per request for each post type and value, and SHALL NOT be rewritten. A lookup
that fails SHALL be logged with the error.

#### Scenario: A stored value the check would refuse

- **WHEN** a post type's stored option names a class that is not a post decorator, or a name that
  cannot be loaded
- **THEN** its posts SHALL decorate with the default decorator, rendering SHALL succeed, one warning
  SHALL be logged per request, and the stored option SHALL be unchanged

#### Scenario: No post type

- **WHEN** a post has no post type
- **THEN** it SHALL decorate with the default decorator

#### Scenario: Options that cannot be read

- **WHEN** a post's post type has an options row that is not a JSON object
- **THEN** the post SHALL decorate with the default decorator without a lookup failure, and the row
  is reported by the scan task

### Requirement: Stored values that would be refused are reported

The `camaleon_cms:security:scan_content` task SHALL list every post type whose stored decorator
option would be refused by the save-time check, a name that cannot be loaded included, naming the
post type and the value, and every post type whose options cannot be read; one such post type SHALL
NOT end the scan. The task SHALL modify nothing.

#### Scenario: A post type with a rejected stored value

- **WHEN** the task runs while a post type's stored option names a class that is not a post
  decorator
- **THEN** the report SHALL name that post type and the value

#### Scenario: A post type whose options cannot be read

- **WHEN** the task runs while a post type's options row is not a JSON object
- **THEN** the report SHALL name that post type and go on to the post types after it

#### Scenario: A post type with a valid or blank option

- **WHEN** the task runs while a post type's option is blank or names a post decorator subclass
- **THEN** the report SHALL NOT list that post type
