## Purpose

The admin JavaScript shows a value as text. A value with markup adds no element to the admin page.

## ADDED Requirements

### Requirement: The tag editor shows a tag name as text

The tag editor of the post form SHALL show each tag name as text. A name with markup MUST NOT add
an element to the form. When the admin opens a tag, the input of the tag SHALL hold the whole name.

#### Scenario: A stored tag name with a tag

- **WHEN** an admin opens the edit form of a post with a tag whose name holds an `img` tag with an
  `onerror` handler
- **THEN** the tag editor shows the whole name as text and adds no `img` element

#### Scenario: A link with the tags param

- **WHEN** an admin opens the form of a new post through a GET link whose `tags` param holds an `img`
  tag
- **THEN** the tag editor shows the value as text and adds no `img` element

#### Scenario: The admin opens a tag whose name holds a quote

- **WHEN** the admin opens a tag whose name holds a double quote and an `onfocus` attribute
- **THEN** the input of the tag holds the whole name and has no `onfocus` attribute
