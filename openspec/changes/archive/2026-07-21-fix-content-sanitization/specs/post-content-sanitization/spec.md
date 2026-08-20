## ADDED Requirements

### Requirement: Untrusted users' post content is sanitized at save time
The system SHALL apply server-side HTML sanitization to `Post#content` when the current user lacks the `post_unfiltered_html` permission for the associated post type. Dangerous tags and attributes (including `<script>`, `<iframe>`, event handlers like `onerror`/`onload`, and `javascript:` URLs) MUST be stripped before persistence. Safe tags (paragraphs, headings, lists, links, images, basic formatting) SHALL be preserved.

#### Scenario: Contributor saves post with script tag
- **WHEN** a contributor (role with only `edit` permission, without `allow_unfiltered_html`) creates or updates a post with content containing `<script>alert(1)</script>`
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

### Requirement: Trusted users' post content bypasses sanitization
The system SHALL store post content unchanged (no sanitization) when the current user has the `post_unfiltered_html` permission for the associated post type. This preserves backward compatibility for administrators and trusted editors who need raw HTML capabilities.

#### Scenario: Admin saves post with embedded content
- **WHEN** an admin (who has `can :manage, :all` or explicit `allow_unfiltered_html` permission) saves a post with content containing `<iframe src="https://example.com/embed"></iframe>`
- **THEN** the persisted content SHALL contain the `<iframe>` element unchanged

#### Scenario: Editor with unfiltered_html permission saves script
- **WHEN** a user with the `editor` role that has `allow_unfiltered_html` enabled on the post type saves post content with `<script>validAppCode()</script>`
- **THEN** the persisted content SHALL contain the `<script>` element unchanged

### Requirement: allow_unfiltered_html permission key exists in the role system
The system SHALL define an `allow_unfiltered_html` key in `UserRole::ROLES[:post_type]` that can be assigned per post type per role. The key MUST be surfaced in the admin UI alongside existing post-type permission keys.

#### Scenario: Admin can grant unfiltered HTML permission to a role
- **WHEN** an admin edits a role's post-type permissions in the admin panel
- **THEN** an `allow_unfiltered_html` checkbox or toggle SHALL be present for each post type
- **AND** enabling it SHALL persist the setting for that role and post type

#### Scenario: Default admin role has unfiltered HTML permission
- **WHEN** a new site is created with default roles (seeded via `SiteDefaultSettings`)
- **THEN** the admin role SHALL have `allow_unfiltered_html` enabled (via `can :manage, :all`)
- **AND** the contributor role SHALL NOT have `allow_unfiltered_html` enabled

### Requirement: Content sanitization does not apply when user context is absent
The system SHALL apply strict sanitization (same as untrusted user) when no user context is available (background jobs, rake tasks, console operations) to ensure security by default.

#### Scenario: Background job updates post content without user context
- **WHEN** a background job or rake task updates a post's content
- **AND** `CurrentRequest.user` is nil
- **THEN** the content SHALL be sanitized with the strict allowlist
