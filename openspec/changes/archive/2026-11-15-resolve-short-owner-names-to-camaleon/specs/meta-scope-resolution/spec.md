# meta-scope-resolution Delta

## ADDED Requirements

### Requirement: A short scope name resolves to the Camaleon owner class

`CamaleonRecord.polymorphic_class_for` SHALL resolve a short scope name to the Camaleon class of
that name before it tries a top-level constant. `User` SHALL resolve to the configured user class,
`Main`, `Sidebar` and `Assigned` to their `CamaleonCms::Widget` classes, and another name to
the `CamaleonCms` Active Record model of that name. A name with `::`, and a short name with no
`CamaleonCms` Active Record model, MUST resolve as Rails resolves it.

#### Scenario: A host model has the name of a Camaleon model

- **WHEN** the host app defines a top-level `Post` class, and a meta row of a Camaleon post has the
  `object_class` `Post`
- **THEN** the `owner` of that row is the Camaleon post

#### Scenario: A host model is named User

- **WHEN** the host app defines a top-level `User` class, and the configured user class is another
  class
- **THEN** `User` resolves to the configured user class

#### Scenario: The widget scope name

- **WHEN** a meta row of a widget has the `object_class` `Main`, also when the host app defines a
  top-level `Main` class
- **THEN** the `owner` of that row is the widget

#### Scenario: A short name with no Camaleon model

- **WHEN** a short name has no `CamaleonCms` Active Record model, such as `Ability`
- **THEN** it resolves to the top-level class of that name

#### Scenario: A name with a namespace

- **WHEN** a name has `::`, such as `Plugins::Shop::Post`
- **THEN** it resolves to the class of that name
