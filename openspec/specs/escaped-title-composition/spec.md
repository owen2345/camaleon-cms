# escaped-title-composition Specification

## Purpose

Combine an already-escaped value with other text without dropping its safeness. Camaleon escapes titles at the source — `PostDecorator#the_title` and `TermTaxonomyDecorator#the_title` return an escaped `ActiveSupport::SafeBuffer` — because most themes and plugins live in separate gems and many render titles through `raw`. That contract is what makes those unseeable sinks safe, and it is not negotiable from inside this repository.

It does, however, put a burden on every caller. A `SafeBuffer` interpolated into a plain Ruby string is just a `String`, and an escaping sink then escapes it a second time, so the reader sees `Ben &amp; Jerry&#39;s` where the name should be. The rule is the same in element and attribute context: pass the value as an argument to a composition helper, never interpolate it.

Three sink families give three different outcomes for the same interpolation, which is why this went unnoticed for so long. ERB `<%= %>` escapes again and is broken; `raw` does not escape and is correct by accident; `display_meta_tags` normalizes through `strip_tags`, unescaping and re-escaping, and absorbs the extra layer. Only the first family needs fixing, and the correct fix is at the composition site, not at the sink — rewriting a sink to `raw` renders correctly today but makes its safety depend entirely on `the_title` continuing to escape, which is how the underlying vulnerability returns.

The third requirement covers a failure that looks like the same bug but is not: applying a transformation such as `titleize` to a value that is already escaped corrupts its entities rather than doubling them, and no amount of correct composition repairs that. Complements [`generated-markup-escaping`](../generated-markup-escaping/spec.md), which governs building markup outside a template; this capability governs composing values that arrive already escaped.

## Requirements
### Requirement: Escaped decorator values MUST be composed without string interpolation

`PostDecorator#the_title` and `TermTaxonomyDecorator#the_title` (and its subclasses' inherited implementation) return an already-escaped `ActiveSupport::SafeBuffer`. Any caller combining such a value with other text SHALL pass it as an argument to a composition helper — `safe_join`, `content_tag`, `link_to`, or an HTML attribute value — and SHALL NOT interpolate it into a plain Ruby string that is subsequently rendered by an escaping sink.

The escaping contract of `the_title` itself is unchanged: it continues to return escaped output, because sinks outside this repository depend on it.

#### Scenario: A site name containing HTML metacharacters renders literally in the settings heading

- **WHEN** a site is named `Ben & Jerry's <b>x</b>`
- **AND** an administrator opens the site settings page
- **THEN** the heading text reads `Configuration Site: Ben & Jerry's <b>x</b>`
- **AND** the page contains no `<b>` element originating from the site name

#### Scenario: A post title containing HTML metacharacters renders literally in the edit form heading

- **WHEN** a post is titled `Ben & Jerry's <b>x</b>`
- **AND** an administrator opens that post's edit form
- **THEN** the heading text reads `Edit Post: Ben & Jerry's <b>x</b>`
- **AND** the page contains no `<b>` element originating from the post title

#### Scenario: A post type name renders literally in the categories and tags headings

- **WHEN** a post type is named `Ben & Jerry's <b>x</b>`
- **AND** an administrator opens that post type's categories page and its tags page
- **THEN** each heading reads the name literally, with no stray entities
- **AND** neither page contains a `<b>` element originating from the name

#### Scenario: A site name renders literally in the sites form heading

- **WHEN** an existing site named `Ben & Jerry's <b>x</b>` is opened for editing
- **THEN** the heading reads the name literally
- **AND** the page contains no `<b>` element originating from the name

#### Scenario: A category name renders literally in the custom field placement select

- **WHEN** a category is named `Ben & Jerry's <b>x</b>`
- **AND** an administrator opens the custom fields form containing the category select
- **THEN** the option text and its `data-help` attribute both read the name literally
- **AND** the page contains no `<b>` element originating from the name

#### Scenario: Already-correct sinks are unchanged

- **WHEN** a post is titled `Ben & Jerry's <b>x</b>`
- **AND** an administrator opens the post list
- **THEN** the post's title cell reads `Ben & Jerry's <b>x</b>` exactly as before the change

### Requirement: `cama_pluralize_text` MUST preserve the safeness of its input

`cama_pluralize_text` SHALL return an `ActiveSupport::SafeBuffer` when given one, and a plain `String` otherwise. It SHALL NOT mark unsafe input as safe.

#### Scenario: A safe input yields a safe result

- **WHEN** `cama_pluralize_text` is given an escaped `SafeBuffer`
- **THEN** the result is pluralized and `html_safe?` is true

#### Scenario: An unsafe input yields an unsafe result

- **WHEN** `cama_pluralize_text` is given a plain `String` containing `<b>x</b>`
- **THEN** the result is pluralized and `html_safe?` is false

#### Scenario: A nil input is unchanged

- **WHEN** `cama_pluralize_text` is given `nil`
- **THEN** the result is `nil`

### Requirement: Text transformations MUST be applied before escaping, not after

Code applying a string transformation such as `titleize` to a translatable name SHALL apply it to the unescaped value and allow the rendering sink to escape the result. Applying such a transformation to an already-escaped value corrupts HTML entities — `"Ben &amp; Jerry&#39;s".titleize` yields `"Ben &Amp; Jerry&#39;S"`, and `&Amp;` is not a valid entity.

#### Scenario: A titleized category name in a tooltip renders without corrupted entities

- **WHEN** a category is named `Ben & Jerry's`
- **AND** an administrator opens the categories list for its post type
- **THEN** the row's action-button `title` attribute contains `Ben & Jerry's` with correct entity encoding
- **AND** it does not contain `&Amp;`
