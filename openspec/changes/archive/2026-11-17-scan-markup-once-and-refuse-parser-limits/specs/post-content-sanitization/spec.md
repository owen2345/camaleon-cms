## ADDED Requirements

### Requirement: The markup gate reads each element once

The markup gate (`CamaleonCms::UnsafeMarkup.unsafe_html?`) SHALL get the elements of its parse from
one walk of the tree, with no recursion. It SHALL NOT search the parsed fragment with `css`. Such a
search runs once for each top-level node, and its cost grows with the square of their number. The
gate SHALL see every element of a value, the elements of its last translated block too.

#### Scenario: A value with many translated blocks

- **WHEN** a value has 600 translated blocks, and a `css` search of a fragment raises an error
- **THEN** the gate accepts the value when it is clean, and accepts a benign style in the last block
- **AND** the gate refuses a disallowed tag, dangerous css, or markup in an attribute in the last
  block

### Requirement: The markup gate refuses a value that its parser cannot read

The markup gate SHALL refuse a value when its parser raises an error for it. The HTML5 parser raises
`ArgumentError` past 400 nested elements, or past 400 attributes on one element. The save SHALL fail
with the disallowed-markup error, and SHALL NOT raise.

#### Scenario: Content nested deeper than the parser reads

- **WHEN** a contributor saves post content with 401 nested elements
- **THEN** the save SHALL fail with the disallowed-markup error on `content`, and nothing SHALL be
  persisted
- **AND WHEN** the content has 399 nested elements and no other disallowed markup
- **THEN** the gate SHALL accept it

#### Scenario: An element with too many attributes

- **WHEN** a value has an element with 401 attributes
- **THEN** the gate SHALL refuse it
