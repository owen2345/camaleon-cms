# generated-markup-escaping Specification

## Purpose

Keep HTML fragments that are assembled outside a template safe at the point they are built, rather than at the point they are rendered. Camaleon escapes user data at the source — `the_title` returns an already-escaped `SafeBuffer` — because most themes and plugins live in separate gems and many render those values through `raw`. Escaping at the source is what makes those unseeable sinks safe, so a decorator, helper or model that builds markup by interpolation must uphold the same contract: escape every interpolated value that is not already a `SafeBuffer`, and return one.

The second requirement records why fixing the sink is the property worth having for post statuses specifically: three writers reach `posts.status` without model validation, so no amount of validation at the model or controller layer makes the column trustworthy to rendering code.

Escaping must not change the output for data containing no HTML metacharacters. Downstream themes have had years to match on the exact bytes of these fragments, and this repo cannot see them — so the fix is applied to the interpolated value, never by restructuring the surrounding markup. Complements [`html-attribute-escaping`](../html-attribute-escaping/spec.md), which covers the attribute context rather than the element body.

## Requirements
### Requirement: HTML fragments built outside a view MUST escape the data they interpolate

Code that assembles an HTML string outside a template — a decorator, a helper, or a model — and whose result is rendered through `raw` or `html_safe` SHALL escape every interpolated value that is not already an `ActiveSupport::SafeBuffer`, and SHALL return a `SafeBuffer`.

This applies to `PostDecorator#the_status`, `TermTaxonomyDecorator#the_status`, and `CustomFieldGroup#get_caption`.

The escaped output MUST remain byte-identical to the current output for values that contain no HTML metacharacters, so that downstream themes matching on the rendered markup are unaffected.

#### Scenario: A non-canonical post status renders as inert text

- **WHEN** a post's `status` column holds `x'><script src=//evil.example/a.js></script>`
- **AND** an administrator opens the post list for that post type with `s=all`
- **THEN** the response contains no `<script>` element inside `#posts-table-list`
- **AND** the payload is present as escaped text within the status label

#### Scenario: A canonical post status renders unchanged

- **WHEN** a post's `status` is `published`, `pending`, `draft`, `draft_child`, or `trash`
- **THEN** `the_status` returns exactly `<span class='label label-<color> label-form'><Label></span>` as before the change
- **AND** the value is an `ActiveSupport::SafeBuffer`

#### Scenario: The poisoned status does not execute on the post edit form

- **WHEN** a post's `status` column holds a script payload
- **AND** an administrator opens that post's edit form
- **THEN** the response contains no `<script>` element originating from the status label

#### Scenario: The poisoned status does not execute in admin search

- **WHEN** a post's `status` column holds a script payload
- **AND** an administrator runs an admin search with `kind=content` that matches the post
- **THEN** the response contains no `<script>` element originating from the status label

#### Scenario: A field group caption escapes an injected nav menu name

- **WHEN** a nav menu is named `<script src=//evil.example/a.js></script>`
- **AND** a custom field group is placed on that nav menu
- **AND** an administrator opens the custom fields settings page
- **THEN** the response contains no `<script>` element originating from the caption
- **AND** the menu name is present as escaped text inside the caption

#### Scenario: A field group caption escapes an injected widget name

- **WHEN** a widget is named with a script payload
- **AND** a custom field group is placed on that widget
- **AND** an administrator opens the custom fields settings page
- **THEN** the response contains no `<script>` element originating from the caption

#### Scenario: A field group caption escapes an injected theme name

- **WHEN** a theme record is named with a script payload
- **AND** a custom field group is placed on that theme
- **AND** an administrator opens the custom fields settings page
- **THEN** the response contains no `<script>` element originating from the caption

#### Scenario: A field group caption escapes an injected object class

- **WHEN** a custom field group is stored with an `object_class` carrying a script payload and the current site's id as `objectid`
- **AND** an administrator opens the custom fields settings page
- **THEN** the response contains no `<script>` element originating from the caption
- **AND** the class name is present as escaped text inside the caption

#### Scenario: A caption for a legitimate placement renders unchanged

- **WHEN** a custom field group is placed on a nav menu named `Main Menu`
- **THEN** the caption is exactly `Field settings for Menus <b>(Main Menu)</b>` as before the change

### Requirement: The post status column MUST NOT be trusted as canonical by rendering code

Three writers reach `posts.status` without model validation — `PostsController#trash` and `#restore` via `update_column`, and `DraftsController` via `save(validate: false)`. Rendering code SHALL therefore treat the column as untrusted input regardless of any validation applied at the model or controller layer.

#### Scenario: A status poisoned through the restore path still renders inert

- **WHEN** a user stores a script payload in `options[:status_default]` on a post
- **AND** the post is trashed and then restored, writing the payload to `status` via `update_column`
- **AND** an administrator opens the post list with `s=all`
- **THEN** the response contains no `<script>` element inside `#posts-table-list`

