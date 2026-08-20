## Context

Camaleon CMS uses a `normalize_attrs` concern that applies Rails' `ActionController::Base.helpers.sanitize()` to model attributes. This was introduced as a blanket XSS defense, but the approach has two critical flaws:

**False negatives (missed XSS):** `Post#content` is NOT normalized, yet templates render it with `raw @post.the_content` in 12+ bundled theme files. Any authenticated user with post-editing rights can store arbitrary HTML/scripts that execute for all visitors.

**False positives (data loss):** `Meta#value` stores serialized JSON (site settings, email configuration). `sanitize()` treats angle brackets as HTML tags and strips them, silently destroying content like `My Name <myemail@domain.com>` → `My Name `. This also affects name fields on User, Site, Category, etc., where angle brackets in user input get stripped.

The existing `normalize_attrs` is applied to 13 models, but only `PostComment#content` genuinely contains user-submitted rich HTML that needs sanitization.

The role/permission system (`UserRole::ROLES[:post_type]`, CanCanCan `Ability`) already supports per-post-type, per-role granularity with 9 existing permission keys. It has no concept of "trusted for HTML" vs "untrusted".

## Goals / Non-Goals

**Goals:**
- Prevent stored XSS in post content from non-admin/trusted users via server-side allowlisting
- Preserve raw HTML capability for trusted roles (backward compatibility)
- Stop `normalize_attrs` from destroying angle-bracket content in plain-text and structured-data fields
- Introduce a `allow_unfiltered_html` permission key into the existing role system
- Reorder the content pipeline so sanitization runs before shortcode expansion
- Add tests that reproduce the XSS vulnerability and the email scrubbing bug

**Non-Goals:**
- Adding a Content-Security-Policy header (separate defense-in-depth concern)
- Changing how TinyMCE or client-side editors filter content
- Changing the block-DSL `the_post { the_content }` path (already fixed via `sanitize()` in the helper)
- Modifying third-party theme templates (only bundled themes)
- Removing `<%= raw %>` from templates (it's still needed for trusted HTML; `raw` on sanitized content is safe)

## Decisions

### Decision 1: Sanitize at save time, not render time

**Choice:** Apply sanitization in the model layer (`normalize_attrs`) or controller (`get_post_data`), not in templates or decorators.

**Rationale:** Templates use `raw @post.the_content` intentionally to allow rich HTML. If we strip at render time, trusted users lose rich content. By sanitizing at save time, the database holds what is safe to render, and templates don't need to change behavior. The `raw` wrapper is safe when the stored content is already sanitized.

**Alternatives considered:**
- *Sanitize in `PostDecorator#the_content`:* Would strip shortcode-generated HTML (iframes, embeds) and trusted-user content. Would break backward compatibility.
- *Sanitize at render time only for untrusted users:* Complex to implement per-user rendering decisions in templates. Adds runtime overhead.

### Decision 2: Use `normalize_attrs` for `Post#content` with a configurable sanitizer

**Choice:** Add `normalize_attrs(:content)` to the Post model, with the sanitization behavior conditioned on the current user's permissions (checked via `current_user` from `CurrentRequest`). When `can?(:post_unfiltered_html, post_type)` is true, skip sanitization. Otherwise, use a strict allowlist.

**Rationale:** `normalize_attrs` already exists and 13 models use it. The `current_user` is available on models via `CurrentRequest.user`. This keeps the filtering at the model layer where it can't be bypassed by custom controllers or API endpoints.

**Alternatives considered:**
- *Sanitize only in `PostsController#get_post_data`:* Controller-only filtering can be bypassed by plugins, importers, or API endpoints that write directly to the model.
- *New separate sanitization concern:* Adds complexity without benefit over extending the existing `normalize_attrs`.

### Decision 3: Remove `normalize_attrs` from plain-text fields, not make them smarter

**Choice:** Remove `normalize_attrs(:name)` and `normalize_attrs(:description)` from models where these are plain-text display fields. Keep only `normalize_attrs(:content)` on `PostComment` and add it to `Post`.

**Rationale:** Plain-text fields are rendered via `<%= @user.first_name %>` which Rails auto-escapes to `&lt;script&gt;`. No storage-time sanitization is needed. ERB escaping is the correct defense for plain text. The current sanitization causes data loss (email angle brackets, intentional formatting characters made into text by escaping) without adding security value.

For `description` fields where HTML might be intentional (e.g., category descriptions with links), we keep `normalize_attrs` only on fields explicitly documented as supporting rich HTML. Current descriptions use ERB escaping in templates, so removing `normalize_attrs` is safe.

**Alternatives considered:**
- *Use escape-once-safe list:* A configurable list of models/fields to skip. Adds indirection. Removing from plain-text models is simpler and more explicit.
- *Never sanitize descriptions, use ERB:* Works for all current description rendering because templates use `<%= %>` (auto-escaped). But if a future template uses `raw` on a description, XSS would be possible. Accept this risk — the solution is to use ERB escaping, not strip at storage.

### Decision 4: New `allow_unfiltered_html` permission key in `UserRole::ROLES[:post_type]`

**Choice:** Add a single new key `allow_unfiltered_html` to the existing `[post_type]` permissions in `UserRole::ROLES`. Wire it through `Ability` as `can :post_unfiltered_html, CamaleonCms::PostType`. Default: enabled for admin role only.

**Rationale:** The existing permission system is per-post-type, per-role, and admin-UI-editable. Adding one key fits the existing architecture perfectly. No new role types, controllers, or views needed beyond the key definition and ability rule.

**Alternatives considered:**
- *New user column (user.trusted_for_html):* Hardcoded, not per-post-type, requires migration.
- *Site-level setting:* Too coarse — all or nothing for the entire site.

### Decision 5: Reorder pipeline to sanitize → hooks → shortcodes

**Choice:** In the `normalize_attrs` callback for Post, sanitize happens before validation. Shortcodes are expanded at render time in the decorator. Since sanitization is at save time and shortcode expansion is at render time, the pipeline is naturally: sanitize → save → read → hooks → shortcodes. No explicit reordering needed in code — it's a consequence of sanitizing at the model layer.

**Rationale:** The existing pipeline is `content → hooks → shortcodes` in the decorator. By moving sanitization to the model's `before_validation` callback (which is how `normalize_attrs` works), sanitization runs before any rendering. Shortcodes in stored content are sanitized as plain text (stripped if disallowed, preserved if allowed). When the decorator later expands them, the shortcode itself is safe because it was already filtered.

### Decision 6: Limit `description` field normalization removal to fields proven to cause data loss

**Choice:** Remove `normalize_attrs` from `:name` fields on affected models. Keep `:description` normalization for now on models where descriptions may legitimately contain user HTML (categories, post types, etc.), since stripping HTML from descriptions is arguably a feature (prevents styling leaks).

**Rationale:** The confirmed bug is in Meta#value and name fields. Description fields are debatable — removing sanitization could allow HTML in descriptions to render through any template that uses `raw`. Keep description normalization until separately evaluated.

Actually revised: We'll remove normalization from all `:name` fields across all models, and also from `Meta#value`. For `:description` fields, we'll keep existing behavior since the issue only reports problems with names and structured data.

## Risks / Trade-offs

- **[Risk] Breaking change for sites that rely on sanitize() stripping formatting from names:** If any site has grown dependent on name fields being stripped of HTML, removing `normalize_attrs` changes behavior. → **Mitigation:** Names are rendered with ERB auto-escaping, so HTML in names becomes harmless text. This is a data integrity bug fix, not a behavior regression.

- **[Risk] Untrusted users can still inject XSS via shortcodes:** If a shortcode handler generates `<script>` tags, sanitizing before shortcodes won't catch it. → **Mitigation:** Shortcode handlers are written by developers/plugins, not end users. We document that shortcode output should be escaped. This is not a new risk — it exists today.

- **[Risk] Concurrent request with different user context:** `normalize_attrs` reads `CurrentRequest.user`, which is per-thread. In background jobs or rake tasks, `current_user` may be nil. → **Mitigation:** When `current_user` is nil (background job, import), default to strict sanitization. Admin imports can explicitly skip callbacks if needed.

- **[Risk] Admin who posts XSS payloads:** The `allow_unfiltered_html` permission means admins can still store XSS. → **Mitigation:** This is by design — admin is a trusted role. Same as any CMS (WordPress, etc.). Defense-in-depth (CSP) is a separate concern.

## Migration Plan

1. Deploy with both fixes simultaneously: remove `normalize_attrs` from plain-text fields and add it to Post with role-based logic.
2. No database migrations needed. The `allow_unfiltered_html` key is stored in existing JSON meta columns.
3. Existing sites: admin role gets `allow_unfiltered_html` by default on new seed. For existing sites, admins already have `can :manage, :all` which grants the new permission automatically.
4. Rollback: revert to previous state. Content stored under the new system may have stricter filtering for non-admins, but no data is permanently lost (the pre-sanitization content would need to be re-entered).

## Open Questions

- Should `description` fields also have `normalize_attrs` removed, or only `name` fields? Current decision: keep on descriptions (safer, no reported data loss).
- Should the sanitizer allowlist be configurable per site or per post type, or is a single global allowlist sufficient? Current decision: single global allowlist. Can be extended later.
- Should we add a `sanitized_content` variant alongside raw content for backward compatibility, similar to how `content_filtered` already exists? Current decision: no — sanitized content replaces raw content for untrusted users at save time.
