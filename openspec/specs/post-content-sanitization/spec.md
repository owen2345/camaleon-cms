# post-content-sanitization

## Purpose

Prevent stored XSS via post content by refusing to save dangerous content from untrusted users
(scan-and-reject: the save fails with an error, content is never sanitized or rewritten), while
preserving raw HTML capability for trusted roles (admins and roles with the
`post_content_unfiltered_html` permission). Stored content therefore always equals authored
content, which is what makes rendering it with `raw @post.the_content` safe.

## Requirements

### Requirement: post_content_unfiltered_html permission key exists in the role system

The system SHALL define a `post_content_unfiltered_html` key in `UserRole::ROLES[:post_type]` that
can be assigned per post type per role. The key MUST be surfaced in the admin UI alongside existing
post-type permission keys.

#### Scenario: Admin can grant unfiltered HTML permission to a role

- **WHEN** an admin edits a role's post-type permissions in the admin panel
- **THEN** a `post_content_unfiltered_html` checkbox or toggle SHALL be present for each post type
- **AND** enabling it SHALL persist the setting for that role and post type

#### Scenario: Default admin role has unfiltered HTML permission

- **WHEN** a new site is created with default roles (seeded via `SiteDefaultSettings`)
- **THEN** the admin role SHALL have `post_content_unfiltered_html` enabled (via `can :manage, :all`)
- **AND** the editor role SHALL NOT have `post_content_unfiltered_html` enabled by default — it is
  explicitly skipped during seed to prevent non-admin editors from storing raw scripts
- **AND** the contributor role SHALL NOT have `post_content_unfiltered_html` enabled

### Requirement: The post-content key is distinct from the contact-form key

The key name SHALL state its subject. It governs `Post#content` (and, per the
`custom-field-value-rejection` capability, a post's gated custom-field values). It is distinct from
the manager-family key `contact_form_unfiltered_html`, which governs contact-form content under
`contact-form-output-escaping`. Holding either SHALL NOT imply the other.

#### Scenario: Holding the post-content grant does not widen contact-form trust

- **WHEN** a user holds `post_content_unfiltered_html` on every post type but not
  `:manage, :contact_form_unfiltered_html`
- **AND** that user saves a contact form whose `previous_html` contains `<script>alert(1)</script>`
- **THEN** the save SHALL be refused and nothing SHALL be persisted

### Requirement: The post-content permission is checked under the name of its key

The system SHALL check the permission as `can?(:post_content_unfiltered_html, post_type)`. The
ability name and the role-meta key are deliberately identical, as manager-family keys resolve
through `Ability#define_manage_rules`. Both capabilities share the same remedy: the system SHALL
refuse a save that the author is not permitted to make outright, and never rewrite it.

#### Scenario: A role with the key passes the ability check

- **WHEN** a role holds the `post_content_unfiltered_html` key on a post type
- **THEN** `can?(:post_content_unfiltered_html, post_type)` is true for a user with that role

### Requirement: Untrusted users' dangerous post content is rejected at save time

The system SHALL refuse to save `Post#content` when the current user lacks the
`post_content_unfiltered_html` permission for the associated post type and the content contains
markup outside the post allowlist or structurally deceptive markup. The refusal SHALL be a validation
error on `content` naming the remedy (remove the markup or obtain the permission). Content SHALL
NEVER be sanitized, stripped, or otherwise rewritten: it is stored exactly as authored or not stored
at all.

#### Scenario: Contributor saves post with script tag

- **WHEN** a contributor (role with only `edit` permission, without `post_content_unfiltered_html`)
  creates or updates a post with content containing `<script>alert(1)</script>`
- **THEN** the save SHALL fail with a validation error on `content`, and nothing SHALL be persisted

#### Scenario: Pre-gate stored content stays editable while untouched

- **WHEN** a post whose stored content predates the gate (and would fail it) is updated without
  changing `content`
- **THEN** the save SHALL succeed; changing the content itself SHALL re-run the gate

### Requirement: The content gate refuses these kinds of markup

The content gate SHALL refuse each of these kinds of markup from an untrusted user:

- script elements
- `<iframe>`
- event-handler attributes
- script-capable URI schemes
- css the scrubber would refuse
- tags the parser drops or leaves open
- translation markers inside tags
- non-marker comments
- values beyond the parse bound

#### Scenario: Contributor saves post with SVG-based XSS

- **WHEN** a contributor saves a post with content containing
  `<svg xmlns="http://www.w3.org/2000/svg"><animate onbegin="alert(document.domain)"/></svg>`
- **THEN** the save SHALL fail with a validation error on `content`

#### Scenario: Contributor saves post with javascript URL in link

- **WHEN** a contributor saves a post with content containing `<a href="javascript:alert(1)">click</a>`
- **THEN** the save SHALL fail with a validation error on `content`

#### Scenario: Contributor saves post with event handlers on allowed tags

- **WHEN** a contributor saves post content with `<img src="x" onerror="alert(1)">`
- **THEN** the save SHALL fail with a validation error on `content` — the payload SHALL NOT be
  stripped and stored

#### Scenario: A stray HTML comment is refused

- **WHEN** a contributor saves content containing `<!-- hidden -->` (not a translation marker)
- **THEN** the save SHALL fail with a validation error on `content`

### Requirement: The post allowlist is the sanitizer default plus structural markup

The post allowlist SHALL be the sanitizer default widened with this structural, non-executable markup
that long-form content legitimately uses:

- table elements: `table`, `thead`, `tbody`, `tfoot`, `tr`, `td`, `th`, `caption`, `col`, `colgroup`
- `figure`, `figcaption`, `u`, `s` and `hr`
- the attributes `id`, `style` (css-scrubbed), `target`, `rel`, `colspan` and `rowspan`
- `data-*` and `aria-*` attributes, admitted by shape

#### Scenario: Contributor's table markup is preserved

- **WHEN** a contributor saves post content containing
  `<table><thead><tr><th>H</th></tr></thead><tbody><tr><td colspan="2">cell</td></tr></tbody></table>`
- **THEN** the save SHALL succeed and the persisted content SHALL equal the authored content exactly

#### Scenario: Contributor's layout attributes survive but script vectors do not

- **WHEN** a contributor saves `<p id="lead" style="color:red">t</p><a href="/x" target="_blank" rel="noopener">l</a>`
- **THEN** the save SHALL succeed and the persisted content SHALL equal the authored content
  exactly, css whitespace included
- **AND WHEN** the same content additionally carries an `onclick` attribute
- **THEN** the save SHALL fail with a validation error — no stripped variant SHALL be stored

### Requirement: An attribute admitted by shape does not admit markup in its value

Admitting an attribute by shape SHALL NOT admit markup carried in its value. The gate SHALL refuse a
value that decodes to a tag-open, even when it is entity-encoded so that no literal `<` is stored.
This is because a client-side `data-html` sink, such as a Bootstrap tooltip or popover, injects it as HTML.

#### Scenario: Markup smuggled through an attribute value is refused

- **WHEN** a contributor saves content whose `data-*` (or an allowed attribute like `title`) value
  decodes to markup, e.g. `<a data-html="true" data-content="&lt;img src=x onerror=alert(1)&gt;">x</a>`
- **THEN** the save SHALL fail with a validation error on `content` — a benign `data-*` value with no
  markup still saves

### Requirement: A value beyond the parse bound is refused with a size-specific error

The parse-size bound is generous: multiple megabytes. The gate SHALL refuse a value beyond it with a
size-specific error that differs from the markup error. An over-size value can be perfectly clean.

#### Scenario: Over-size content is refused with a size-specific message

- **WHEN** a contributor saves content beyond the parse-size bound
- **THEN** the save SHALL fail with a size-specific error on `content`, not the disallowed-markup error
- **AND WHEN** a long but clean post within the bound is saved
- **THEN** the save SHALL succeed

### Requirement: Trusted users' post content bypasses the content gate

The system SHALL store post content unchanged, with no gate applied, when the current user has the
`post_content_unfiltered_html` permission for the associated post type. This preserves raw HTML
capability for administrators and trusted editors.

#### Scenario: Admin saves post with embedded content

- **WHEN** an admin (who has `can :manage, :all` or explicit `post_content_unfiltered_html`
  permission) saves a post with content containing `<iframe src="https://example.com/embed"></iframe>`
- **THEN** the persisted content SHALL contain the `<iframe>` element unchanged

#### Scenario: Editor with unfiltered_html permission saves script

- **WHEN** a user with the `editor` role that has `post_content_unfiltered_html` enabled on the
  post type saves post content with `<script>validAppCode()</script>`
- **THEN** the persisted content SHALL contain the `<script>` element unchanged

### Requirement: The content gate fails closed when user context is absent

The system SHALL apply the gate (same as for an untrusted user) when no user context is available
(background jobs, rake tasks, console operations): dangerous content SHALL be refused, while benign
content saves normally.

#### Scenario: Background job updates post content without user context

- **WHEN** a background job or rake task updates a post's content with dangerous markup
- **AND** `CurrentRequest.user` is nil
- **AND** the opt-out was not enabled
- **THEN** the save SHALL fail with a validation error on `content`

#### Scenario: Context-free benign content saves

- **WHEN** a background job or rake task saves benign post content with no `CurrentRequest` context
- **THEN** the save SHALL succeed and the content SHALL be stored exactly as authored

### Requirement: A developer-controlled save can opt out of the content gate

The system SHALL also expose an explicit per-record opt-out for developer-controlled saves. Calling
`post.unfiltered_content!` before save SHALL cause the content to be stored unchanged regardless of
user context.

#### Scenario: A trusted pipeline opts a record out of sanitization

- **WHEN** server-side code calls `post.unfiltered_content!` and saves with no `CurrentRequest.user`
- **AND** the content contains `<script>seed()</script>`
- **THEN** the persisted content SHALL contain the `<script>` element unchanged

### Requirement: The opt-out has no mass-assignment writer

The opt-out SHALL be exposed as a reader plus the bang enabler with NO `unfiltered_content=` writer.
So `assign_attributes` and mass assignment cannot reach it, and request parameters cannot set it. It
exists for trusted server-side pipelines (imports, seeds, plugin code) that the fail-closed default
would otherwise refuse.

#### Scenario: The opt-out has no mass-assignment writer

- **WHEN** `unfiltered_content` is supplied in a request-style attributes hash to a new post
- **THEN** no `unfiltered_content=` writer SHALL exist to receive it (mass assignment raises
  `UnknownAttributeError` rather than enabling the opt-out)

### Requirement: The post summary from an untrusted user is held to the content scan

For a user without `post_content_unfiltered_html` on the post type, a post or draft save SHALL be
refused when its `meta[summary]` fails the content scan. The scan uses the
same allowlist and size bound as `Post#content`. The refusal SHALL name the summary field. Nothing
from the save SHALL be stored. The summary SHALL NEVER be sanitized or rewritten.

#### Scenario: An editor's summary with a script is refused

- **WHEN** an editor without `post_content_unfiltered_html` updates a post with `meta[summary]` containing `<script>alert(1)</script>`
- **THEN** the save is refused with an error naming the summary field
- **AND** the stored summary and the post's title are unchanged, and the listing page renders no script element

#### Scenario: A plain summary is stored

- **WHEN** an editor updates a post with `meta[summary]` holding text with a `<b>` element
- **THEN** the save succeeds and the summary is stored as submitted

#### Scenario: A draft autosave is held to the same scan

- **WHEN** an editor without the permission autosaves a draft with a summary containing a script element
- **THEN** the draft save answers with an error naming the summary field and stores nothing

### Requirement: A trusted summary and an older summary are stored as written

An administrator's or permission holder's summary SHALL be stored as written. A summary stored before
the scan existed SHALL NOT be rewritten. The `camaleon_cms:security:scan_content` task lists it.

#### Scenario: A permission holder's summary is stored as written

- **WHEN** an administrator updates a post with `meta[summary]` containing a script element
- **THEN** the save succeeds and the summary is stored as written

#### Scenario: A summary stored before the scan is not rewritten

- **WHEN** a post has a summary that the scan would refuse, stored before the scan existed
- **THEN** the system does not rewrite that summary
- **AND** the `camaleon_cms:security:scan_content` task lists it

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

### Requirement: The scan reads each translation that the page shows

The content scan (`UnsafeMarkup.unsafe_html?`) SHALL read the stored text and each translation that
`String#translate` gives for it. A value SHALL be refused when one of these texts fails a check.
`translate` removes the first marker of the locale on each line, anywhere in the line. So a
translation can join a `<` and the text after a marker into a tag.

#### Scenario: A tag that a translation joins is refused

- **WHEN** a contributor saves post content that holds `<!--:en--><p>Intro</p>`, a line break and
  `<<!--:en-->img src=x onerror=alert(1)><!--:-->`
- **THEN** the save SHALL fail with a validation error on `content`, because the English
  translation shows `<img src=x onerror=alert(1)>`
- **AND** nothing SHALL be persisted

#### Scenario: A summary whose translation joins a tag is refused

- **WHEN** an editor without `post_content_unfiltered_html` saves a summary whose translation joins
  a tag with an event handler
- **THEN** the save SHALL be refused, and no summary SHALL be stored

#### Scenario: Translated content with allowed markup is stored unchanged

- **WHEN** a contributor saves translated content whose translations hold only allowed markup
- **THEN** the save SHALL succeed and the persisted content SHALL equal the authored content
