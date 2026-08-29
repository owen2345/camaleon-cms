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

The key name SHALL state its subject. It governs `Post#content` (and, per the
`custom-field-value-rejection` capability, a post's gated custom-field values), and is distinct from
the manager-family key `contact_form_unfiltered_html`, which governs contact-form content under
`contact-form-output-escaping`. Holding either SHALL NOT imply the other. The permission is checked
as `can?(:post_content_unfiltered_html, post_type)`; the ability name and the role-meta key are
deliberately identical, matching how manager-family keys resolve through
`Ability#define_manage_rules`. Both capabilities share the same remedy: a save the author is not
permitted to make is refused outright, never rewritten.

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

#### Scenario: Holding the post-content grant does not widen contact-form trust

- **WHEN** a user holds `post_content_unfiltered_html` on every post type but not
  `:manage, :contact_form_unfiltered_html`
- **AND** that user saves a contact form whose `previous_html` contains `<script>alert(1)</script>`
- **THEN** the save SHALL be refused and nothing SHALL be persisted

### Requirement: Untrusted users' dangerous post content is rejected at save time

The system SHALL refuse to save `Post#content` when the current user lacks the
`post_content_unfiltered_html` permission for the associated post type and the content contains
anything outside the post allowlist — script elements, `<iframe>`, event-handler attributes,
script-capable URI schemes, css the scrubber would refuse — or structurally deceptive markup (tags
the parser drops or leaves open, translation markers inside tags, non-marker comments, values
beyond the parse bound). The refusal SHALL be a validation error on `content` naming the remedy
(remove the markup or obtain the permission). Content SHALL NEVER be sanitized, stripped, or
otherwise rewritten: it is stored exactly as authored or not stored at all.

The allowlist is unchanged from the sanitize era: the sanitizer default widened with the
structural, non-executable markup long-form content legitimately uses — table elements (`table`,
`thead`, `tbody`, `tfoot`, `tr`, `td`, `th`, `caption`, `col`, `colgroup`), `figure`/`figcaption`,
`u`, `s`, `hr`, and the attributes `id`, `style` (css-scrubbed), `target`, `rel`, `colspan`,
`rowspan` — plus `data-*`/`aria-*` attributes admitted by shape.

Admitting an attribute by shape SHALL NOT admit markup carried in its value: a value that decodes to
a tag-open — entity-encoded so no literal `<` is stored, e.g. `data-content="&lt;img onerror=...&gt;"`
— SHALL be refused, because a client-side `data-html` sink (Bootstrap tooltip/popover and the like)
would inject it as HTML. The parse-size bound is generous (multiple megabytes); a value beyond it
SHALL be refused with a size-specific error distinct from the markup error, since an over-size value
may be perfectly clean.

#### Scenario: Contributor saves post with script tag

- **WHEN** a contributor (role with only `edit` permission, without `post_content_unfiltered_html`)
  creates or updates a post with content containing `<script>alert(1)</script>`
- **THEN** the save SHALL fail with a validation error on `content`, and nothing SHALL be persisted

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

#### Scenario: A stray HTML comment is refused

- **WHEN** a contributor saves content containing `<!-- hidden -->` (not a translation marker)
- **THEN** the save SHALL fail with a validation error on `content`

#### Scenario: Markup smuggled through an attribute value is refused

- **WHEN** a contributor saves content whose `data-*` (or an allowed attribute like `title`) value
  decodes to markup, e.g. `<a data-html="true" data-content="&lt;img src=x onerror=alert(1)&gt;">x</a>`
- **THEN** the save SHALL fail with a validation error on `content` — a benign `data-*` value with no
  markup still saves

#### Scenario: Over-size content is refused with a size-specific message

- **WHEN** a contributor saves content beyond the parse-size bound
- **THEN** the save SHALL fail with a size-specific error on `content`, not the disallowed-markup error
- **AND WHEN** a long but clean post within the bound is saved
- **THEN** the save SHALL succeed

#### Scenario: Pre-gate stored content stays editable while untouched

- **WHEN** a post whose stored content predates the gate (and would fail it) is updated without
  changing `content`
- **THEN** the save SHALL succeed; changing the content itself SHALL re-run the gate

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

The system SHALL also expose an explicit per-record opt-out for developer-controlled saves: calling
`post.unfiltered_content!` before save SHALL cause the content to be stored unchanged regardless of
user context. The opt-out SHALL be exposed as a reader plus this bang enabler with NO
`unfiltered_content=` writer, so `assign_attributes`/mass assignment cannot reach it and request
parameters cannot set it; it exists for trusted server-side pipelines (imports, seeds, plugin code)
that would otherwise be refused by the fail-closed default.

#### Scenario: Background job updates post content without user context

- **WHEN** a background job or rake task updates a post's content with dangerous markup
- **AND** `CurrentRequest.user` is nil
- **AND** the opt-out was not enabled
- **THEN** the save SHALL fail with a validation error on `content`

#### Scenario: Context-free benign content saves

- **WHEN** a background job or rake task saves benign post content with no `CurrentRequest` context
- **THEN** the save SHALL succeed and the content SHALL be stored exactly as authored

#### Scenario: A trusted pipeline opts a record out of sanitization

- **WHEN** server-side code calls `post.unfiltered_content!` and saves with no `CurrentRequest.user`
- **AND** the content contains `<script>seed()</script>`
- **THEN** the persisted content SHALL contain the `<script>` element unchanged

#### Scenario: The opt-out has no mass-assignment writer

- **WHEN** `unfiltered_content` is supplied in a request-style attributes hash to a new post
- **THEN** no `unfiltered_content=` writer SHALL exist to receive it (mass assignment raises
  `UnknownAttributeError` rather than enabling the opt-out)

### Requirement: Untrusted authors' dangerous post tag names are rejected at save time

When a post save submits tag names, each submitted name SHALL be scanned with the shared
unsafe-markup detector under the same allowlist and the same trust gate as post content. For an
author without the unfiltered-content trust, a save containing any dangerous tag name SHALL be
refused with a validation error; names MUST NOT be sanitized, stripped, or otherwise transformed.
Saves that submit no tag names, trusted authors' saves, and previously stored tag names are
unaffected.

#### Scenario: Dangerous tag name refused for an untrusted author

- **WHEN** an untrusted author saves a post whose submitted tags include a name containing
  markup the detector flags (for example `<img src=x onerror=alert(1)>`)
- **THEN** the save is refused with a validation error, no tag is created or associated, and the
  submitted name is stored nowhere

#### Scenario: Plain tag names save normally

- **WHEN** an untrusted author saves a post with ordinary tag names (including multi-word names)
- **THEN** the save succeeds and the names are stored verbatim

#### Scenario: Trusted authors are not gated

- **WHEN** an author with the unfiltered-content trust saves a post with a tag name the detector
  would flag
- **THEN** the save succeeds unchanged, consistent with the content-level trust gate
