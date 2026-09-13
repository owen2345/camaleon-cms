## ADDED Requirements

### Requirement: The post summary from an untrusted user is held to the content scan

A post save or draft save whose `meta[summary]` the content scan would refuse (the same allowlist and size bound as `Post#content`) SHALL be refused, naming the summary field, when the current user lacks the `post_content_unfiltered_html` permission for the post type; nothing from the save SHALL be stored. The summary SHALL NEVER be sanitized or rewritten. An administrator's or permission holder's summary SHALL be stored as written. A summary stored before this requirement SHALL NOT be rewritten; the `camaleon_cms:security:scan_content` task lists it.

#### Scenario: An editor's summary with a script is refused

- **WHEN** an editor without `post_content_unfiltered_html` updates a post with `meta[summary]` containing `<script>alert(1)</script>`
- **THEN** the save is refused with an error naming the summary field
- **AND** the stored summary and the post's title are unchanged, and the listing page renders no script element

#### Scenario: A plain summary is stored

- **WHEN** an editor updates a post with `meta[summary]` holding text with a `<b>` element
- **THEN** the save succeeds and the summary is stored as submitted

#### Scenario: A permission holder's summary is stored as written

- **WHEN** an administrator updates a post with `meta[summary]` containing a script element
- **THEN** the save succeeds and the summary is stored as written

#### Scenario: A draft autosave is held to the same scan

- **WHEN** an editor without the permission autosaves a draft with a summary containing a script element
- **THEN** the draft save answers with an error naming the summary field and stores nothing
