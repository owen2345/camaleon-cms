# post-decorator-class-integrity Specification

## Purpose
A post type's decorator class option is loaded as code, so it may name only a post decorator: any
other value is refused at save, ignored at render in favour of the default decorator, and reported
by the security scan.

## Requirements

### Requirement: The decorator class option names a post decorator

A post type's `cama_post_decorator_class` option SHALL be stored only when it is blank or names a
class that is a subclass of `CamaleonCms::PostDecorator`. Any other value, an unknown class name or
a class outside the decorator hierarchy, SHALL be refused at save with an error naming the option
and the rejected value, and the post type's stored options SHALL be left exactly as they were. The
check SHALL apply to every writer, administrators included, through every way of writing the
option.

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

#### Scenario: Clearing the option

- **WHEN** the option is set to a blank value
- **THEN** it SHALL be accepted and posts of the type SHALL decorate with the default decorator

#### Scenario: Other options are unaffected

- **WHEN** a post type's other options are written without the decorator option
- **THEN** they SHALL be stored as before

### Requirement: A refusal from a save hook surfaces in the admin panel

When a hook run after an admin post type save writes a value the check refuses, the admin panel
SHALL answer with a redirect carrying the refusal as a flash error rather than a server error. The
post type's own attributes, saved before the hook ran, remain saved.

#### Scenario: A hook stores a rejected value

- **WHEN** a hook run after an admin post type save writes a non-decorator class name into the
  option
- **THEN** the response SHALL redirect with the error in the flash, the option SHALL stay unset,
  and posts of the type SHALL decorate with the default decorator

### Requirement: A post resolves its decorator safely

A post SHALL decorate with the class named by its post type's option when that class is a
`CamaleonCms::PostDecorator` subclass, and with `CamaleonCms::PostDecorator` otherwise: a blank
option, a post without a post type, or a stored value that predates the check and would now be
refused. A stored value that is ignored SHALL be logged as a warning naming the post type and the
value, and SHALL NOT be rewritten.

#### Scenario: A stored value that predates the check

- **WHEN** a post type's stored option names a class that is not a post decorator
- **THEN** its posts SHALL decorate with the default decorator, rendering SHALL succeed, a warning
  SHALL be logged, and the stored option SHALL be unchanged

#### Scenario: No post type

- **WHEN** a post has no post type
- **THEN** it SHALL decorate with the default decorator

### Requirement: Stored values that would be refused are reported

The `camaleon_cms:security:scan_content` task SHALL list every post type whose stored decorator
option would be refused by the save-time check, naming the post type and the value, and SHALL
modify nothing.

#### Scenario: A post type with a rejected stored value

- **WHEN** the task runs while a post type's stored option names a class that is not a post
  decorator
- **THEN** the report SHALL name that post type and the value

#### Scenario: A post type with a valid or blank option

- **WHEN** the task runs while a post type's option is blank or names a post decorator subclass
- **THEN** the report SHALL NOT list that post type
