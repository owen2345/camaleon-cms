## Why

The `normalize_attrs` concern applies `sanitize()` uniformly to 13+ models, causing both false negatives (Post content is NOT sanitized, enabling stored XSS via `<%= raw @post.the_content %>`) and false positives (Meta's serialized JSON gets angle-bracket content like `<email@domain.com>` silently destroyed). The root cause is a one-size-fits-all sanitization strategy applied to fundamentally different field types: plain text, rich HTML, and semi-structured data.

## What Changes

- **Add role-based HTML allowlisting for post content**: Untrusted users (contributors) get their content sanitized with a strict allowlist at save time. Trusted users (admins, editors with a new `allow_unfiltered_html` permission) retain existing raw-HTML behavior.
- **Add `allow_unfiltered_html` post-type permission key**: Fits into the existing `UserRole::ROLES[:post_type]` system. Admin UI exposes it per-role, per-post-type.
- **Remove `normalize_attrs` from plain-text fields** where `sanitize()` causes data loss: `Meta#value`, `User#first_name/last_name/username`, `UserRole#name`, `Site#name`, `Category#name`, `PostType#name`, `PostTag#name`, `Plugin#name`, `Theme#name`, `NavMenu#name`, `NavMenuItem#name`, `Widget::Main#name`, `Widget::Sidebar#name`. These fields rely on Rails ERB auto-escaping at render time instead.
- **Keep `normalize_attrs` on `PostComment#content`** (already correct) and **add it to `Post#content`** with configurable behavior.
- **Reorder the content pipeline**: sanitize before shortcode expansion, so shortcode-generated HTML isn't stripped and XSS in shortcode output can't escape.
- **Update bundled theme templates** to use a safe rendering helper instead of raw `@post.the_content` for untrusted content, while preserving raw for trusted content.

## Capabilities

### New Capabilities

- `post-content-sanitization`: Server-side sanitization of post content based on user role, preventing stored XSS from non-admin post editors while preserving raw HTML for trusted users.
- `normalize-attrs-scoping`: Restrict `normalize_attrs` to fields that genuinely contain user-submitted HTML, removing it from plain-text and structured-data fields to prevent data loss (e.g., email addresses in angle brackets).

### Modified Capabilities

_None — these are new capabilities, not modifications to existing spec-level behavior._

## Impact

- **Models**: `Post` (add `normalize_attrs`), `Meta`, `User`, `UserRole`, `Site`, `Category`, `PostType`, `PostTag`, `Plugin`, `Theme`, `NavMenu`, `NavMenuItem`, `Widget::Main`, `Widget::Sidebar` (remove `normalize_attrs` from name fields). `PostComment` unchanged.
- **Authorization**: `UserRole::ROLES`, `Ability`, `SiteDefaultSettings` (new `allow_unfiltered_html` key).
- **Controller**: `PostsController#get_post_data` (conditional sanitization).
- **Decorator**: `PostDecorator#the_content` (pipeline reorder if needed, or handle in the model).
- **Templates**: 12+ bundled theme templates currently using `raw @post.the_content`.
- **Tests**: New specs for post content sanitization with/without permission, regression tests for angle-bracket preservation in user/site/meta fields.
