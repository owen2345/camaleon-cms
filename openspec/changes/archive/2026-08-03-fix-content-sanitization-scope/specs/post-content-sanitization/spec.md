## MODIFIED Requirements

### Requirement: Untrusted users' post content is sanitized at save time
The system SHALL apply server-side HTML sanitization to `Post#content` when the current user lacks the `post_content_unfiltered_html` permission for the associated post type. Dangerous tags and attributes (including `<script>`, `<iframe>`, event handlers like `onerror`/`onload`, and `javascript:` URLs) MUST be stripped before persistence.

The allowlist SHALL preserve the structural, non-executable markup that long-form post content legitimately uses, beyond the sanitizer's minimal default: paragraphs, headings, lists, links, images, basic formatting, and additionally table elements (`table`, `thead`, `tbody`, `tfoot`, `tr`, `td`, `th`, `caption`, `col`, `colgroup`), `figure`/`figcaption`, `u`, `s`, `hr`, and the attributes `id`, `style`, `target`, `rel`, `colspan`, `rowspan`. The `style` attribute SHALL be retained only as scrubbed by the sanitizer (CSS expressions and `url()`/`javascript:` payloads removed). This preservation SHALL NOT weaken the stripping of executable content.

#### Scenario: Contributor saves post with script tag
- **WHEN** a contributor (role with only `edit` permission, without `post_content_unfiltered_html`) creates or updates a post with content containing `<script>alert(1)</script>`
- **THEN** the persisted `content` column SHALL NOT contain `<script>` or any executable JavaScript
- **AND** the safe text content around the script tag SHALL be preserved

#### Scenario: Contributor saves post with SVG-based XSS
- **WHEN** a contributor saves a post with content containing `<svg xmlns="http://www.w3.org/2000/svg"><animate onbegin="alert(document.domain)"/></svg>`
- **THEN** the persisted content SHALL NOT contain the `<animate>` element or the `onbegin` attribute
- **AND** the `<svg>` element itself MAY be present but MUST have no event handler attributes

#### Scenario: Contributor saves post with javascript URL in link
- **WHEN** a contributor saves a post with content containing `<a href="javascript:alert(1)">click</a>`
- **THEN** the persisted content SHALL NOT contain `javascript:` in the href attribute

#### Scenario: Contributor saves post with event handlers on allowed tags
- **WHEN** a contributor saves post content with `<img src="x" onerror="alert(1)">`
- **THEN** the persisted content SHALL NOT contain the `onerror` attribute
- **AND** the `src` attribute SHALL be preserved if safe

#### Scenario: Contributor's table markup is preserved
- **WHEN** a contributor saves post content containing `<table><thead><tr><th>H</th></tr></thead><tbody><tr><td colspan="2">cell</td></tr></tbody></table>`
- **THEN** the persisted content SHALL retain the `<table>`, `<thead>`, `<tbody>`, `<tr>`, `<th>`, and `<td>` elements
- **AND** the `colspan` attribute SHALL be preserved

#### Scenario: Contributor's layout attributes survive but script vectors do not
- **WHEN** a contributor saves `<p id="lead" style="color:red" onclick="alert(1)">t</p><a href="/x" target="_blank" rel="noopener">l</a>`
- **THEN** the persisted content SHALL retain `id`, the scrubbed `style`, `target`, and `rel`
- **AND** the `onclick` attribute SHALL be removed

### Requirement: Content sanitization does not apply when user context is absent
The system SHALL apply strict sanitization (same as untrusted user) when no user context is available (background jobs, rake tasks, console operations) to ensure security by default.

The system SHALL also expose an explicit per-record opt-out for developer-controlled saves: calling `post.unfiltered_content!` before save SHALL cause the content to be stored unchanged regardless of user context. The opt-out SHALL be exposed as a reader plus this bang enabler with NO `unfiltered_content=` writer, so `assign_attributes`/mass assignment cannot reach it and request parameters cannot set it; it exists for trusted server-side pipelines (imports, seeds, plugin code) that would otherwise be sanitized by the fail-closed default.

#### Scenario: Background job updates post content without user context
- **WHEN** a background job or rake task updates a post's content
- **AND** `CurrentRequest.user` is nil
- **AND** the opt-out was not enabled
- **THEN** the content SHALL be sanitized with the strict allowlist

#### Scenario: A trusted pipeline opts a record out of sanitization
- **WHEN** server-side code calls `post.unfiltered_content!` and saves with no `CurrentRequest.user`
- **AND** the content contains `<script>seed()</script>`
- **THEN** the persisted content SHALL contain the `<script>` element unchanged

#### Scenario: The opt-out has no mass-assignment writer
- **WHEN** `unfiltered_content` is supplied in a request-style attributes hash to a new post
- **THEN** no `unfiltered_content=` writer SHALL exist to receive it (mass assignment raises `UnknownAttributeError` rather than enabling the opt-out)
