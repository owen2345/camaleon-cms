## Purpose

Preserve the pre-STI tolerance of the `term_taxonomy.taxonomy` and `posts.post_class` discriminator columns: values that map to no known class instantiate the STI root instead of raising, on both read and write, while built-in values keep resolving to their subclasses.

## Requirements

### Requirement: Unknown discriminator values instantiate the STI root

`CamaleonCms::TermTaxonomy.find_sti_class` and `CamaleonCms::PostDefault.find_sti_class` SHALL
return the STI root (`base_class`) for a discriminator value that maps to no known class, instead
of raising `ActiveRecord::SubclassNotFound`. This applies to both reading existing rows and
creating new records with an explicit discriminator value, matching the pre-STI 2.9.2 behavior
where `taxonomy` and `post_class` were plain string columns.

#### Scenario: Reading an existing row with a custom taxonomy value

- **WHEN** the `term_taxonomy` table holds a row whose `taxonomy` is `custom_tax` (written by a
  plugin or by a 2.9.2-era install)
- **THEN** `TermTaxonomy.find(id)` returns a `CamaleonCms::TermTaxonomy` instance with
  `taxonomy == 'custom_tax'`
- **AND** relation loads that include the row do not raise

#### Scenario: Creating a record with a custom taxonomy value

- **WHEN** code calls `CamaleonCms::TermTaxonomy.new(taxonomy: 'custom_tax', name: 'X')` and saves
- **THEN** the row persists with `taxonomy == 'custom_tax'`

#### Scenario: Reading a posts row with an unknown post_class

- **WHEN** the `posts` table holds a row whose `post_class` names no resolvable class
- **THEN** loading it returns a `CamaleonCms::PostDefault` instance with the column value
  preserved

### Requirement: Built-in discriminator values keep their subclasses

The base-class fallback SHALL NOT change resolution for known values: built-in taxonomy values
(`category`, `post_tag`, `post_type`, `nav_menu`, `nav_menu_item`, `site`, `theme`, `plugin`,
`user_roles`, `widget`, `sidebar`) and post classes (`Post`, `Widget::Assigned`, legacy
`CamaleonCms::`-prefixed names) SHALL continue to instantiate their subclasses.

#### Scenario: A category row still loads as Category

- **WHEN** a row with `taxonomy == 'category'` is loaded through `TermTaxonomy.find`
- **THEN** the instance is a `CamaleonCms::Category`

### Requirement: A discriminator resolving to a non-descendant class is treated as unknown

If a discriminator value camelizes to the name of a class that is not a descendant of the STI
root (e.g. a taxonomy value of `meta` resolving to `CamaleonCms::Meta`), the system SHALL treat
the value as unknown and instantiate the STI root, rather than instantiating an unrelated class
against the wrong table.

#### Scenario: A taxonomy value naming an unrelated class loads as the root

- **WHEN** a `term_taxonomy` row's `taxonomy` is `meta`
- **THEN** loading it returns a `CamaleonCms::TermTaxonomy` instance, not `CamaleonCms::Meta`
