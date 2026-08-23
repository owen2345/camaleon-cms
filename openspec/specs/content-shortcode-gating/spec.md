# content-shortcode-gating Specification

## Purpose
Authoring shortcodes in content that the CMS later expands is a privileged capability: a shortcode makes theme/plugin code emit arbitrary HTML/JS at render, which the save-time content scan cannot judge. This capability gates it behind a default-off `content_shortcodes` permission across every authored surface that `do_shortcode` expands (post content, custom-field values, taxonomy content, widget descriptions), closing the shortcode end-run around `post_content_unfiltered_html`.
## Requirements
### Requirement: Publishing content with shortcodes requires the content_shortcodes permission

Saving authored content that will be expanded by `do_shortcode` — post content, custom-field values, taxonomy content, or widget descriptions — and that contains one or more registered shortcodes SHALL be permitted for a non-administrator role only when that role holds the `content_shortcodes` permission. When the acting user is neither an administrator nor a holder of the permission, the save SHALL be rejected with a validation error that names the reason, and the content SHALL NOT be persisted. Content that contains no registered shortcode SHALL be unaffected by this gate.

#### Scenario: A non-administrator without the permission is refused

- **WHEN** a non-administrator role that does not hold `content_shortcodes` saves post content containing a registered shortcode
- **THEN** the save SHALL be rejected with an error naming the reason
- **AND** the content SHALL NOT be persisted

#### Scenario: The gate covers every expanded surface

- **WHEN** a non-administrator without `content_shortcodes` saves a registered shortcode into a custom-field value, taxonomy content, or a widget description
- **THEN** that save SHALL be rejected the same way as post content

#### Scenario: A non-administrator with the permission is allowed

- **WHEN** a non-administrator role that holds `content_shortcodes` saves content containing a registered shortcode
- **THEN** the save SHALL succeed

#### Scenario: An administrator is allowed

- **WHEN** an administrator saves content containing a registered shortcode
- **THEN** the save SHALL succeed without the permission being present in any role meta

#### Scenario: Content without a registered shortcode is unaffected

- **WHEN** any user saves content that contains no registered shortcode (including bracketed prose such as `[note]` or `[text]`)
- **THEN** the save SHALL NOT be gated by `content_shortcodes`

### Requirement: Registered shortcode names are known at save time

The set of registered shortcode names SHALL be available in the save path without a frontend request. Shortcode providers SHALL declare their shortcode names through a boot-time registration mechanism, and the CMS SHALL aggregate them into a canonical registry that save-time detection consults. Detection SHALL match only names present in this registry, so bracketed text that is not a registered shortcode is never treated as one.

#### Scenario: Detection matches a registered name but not arbitrary brackets

- **WHEN** the registry contains the name `redirect` and content contains `[redirect url="…"]` as well as unrelated bracketed text `[see figure]`
- **THEN** detection SHALL flag the content as containing a shortcode on account of `redirect`
- **AND** unrelated bracketed text alone SHALL NOT be treated as a shortcode

### Requirement: The content_shortcodes permission conforms to security-capability-gating

The `content_shortcodes` permission SHALL be default-off and SHALL follow `security-capability-gating`: seeded onto no role; an administrator satisfies the check through `can :manage, :all` without the key present; an installation whose stored role meta predates the permission reads the absent key as not-granted without a migration; and the gate fails closed — an absent authorization context, a failure while evaluating the permission, or an unavailable shortcode registry SHALL resolve to not-granted / gated, and the save SHALL be refused for a non-administrator.

#### Scenario: An upgraded installation reads the absent key as not-granted

- **WHEN** a role whose stored permission meta predates `content_shortcodes` is evaluated
- **THEN** the permission SHALL read as not-granted with no migration required

#### Scenario: The gate fails closed

- **WHEN** the permission cannot be evaluated, or the shortcode registry is unavailable due to error
- **THEN** the gate SHALL resolve to not-granted / gated, and a non-administrator's save of shortcode-bearing content SHALL be refused

### Requirement: Stored content and rendering are unchanged by the gate

The gate SHALL act only as a save-time authorization decision. It SHALL NOT alter, escape, strip, or sanitize stored content, and it SHALL NOT change how shortcodes are expanded or rendered. Content that was permitted — authored by an administrator or a permission-holder — SHALL be stored and rendered verbatim, exactly as before this capability.

#### Scenario: Permitted shortcode content renders verbatim

- **WHEN** a permitted author's content containing a shortcode is rendered
- **THEN** the shortcode SHALL expand exactly as it did before this capability, with no added escaping or sanitization of the stored content

### Requirement: Shortcodes are neither escaped nor sanitized

Because authorship is gated rather than filtered, the CMS SHALL NOT escape, sanitize, strip, or otherwise transform shortcode syntax, shortcode attributes, or shortcode output — neither when content is saved/updated nor when it is expanded at render. Any pre-existing escaping or sanitizing applied specifically to shortcodes SHALL be removed, provided the authorization gate covers the threat it addressed; any instance the gate does not cover SHALL be recorded rather than silently removed. The `content_shortcodes` authorization check SHALL be the only save-time control specific to shortcodes.

#### Scenario: Shortcode output is emitted verbatim

- **WHEN** a permitted author's shortcode is expanded at render
- **THEN** the shortcode's syntax, attributes, and output SHALL appear exactly as the theme/plugin emits them, with no escaping or sanitizing applied by the CMS

#### Scenario: No shortcode-specific escaping remains on save or render

- **WHEN** the save/update and render paths are audited for escaping or sanitizing applied specifically to shortcodes
- **THEN** none SHALL remain, except any instance explicitly recorded as guarding a threat the authorization gate does not cover

