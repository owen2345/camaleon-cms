# Reject dangerous post content on save instead of sanitizing it

## Why

Post content from untrusted authors was sanitized at save time: disallowed markup was silently
stripped and the mutated content stored. Per the project's security model (maintainer decision,
2026-08-13), untrusted input is **rejected, not transformed** — everywhere. Sanitizing silently
mutates authored content (data loss discovered later), invites probing the sanitizer until a payload
slips through, and made post content the one gated position with a transform remedy while uploads
scan-and-refuse, the contact form rejects, and (as of the sibling M17 change) custom-field values
reject. This aligns post content with the rest: a save an untrusted author is not permitted to make
fails loudly with a validation error, and stored content always equals authored content.

## What Changes

- `Post#sanitize_content` (before_validation mutation) becomes
  `Post#reject_untrusted_dangerous_content` (validation): content outside the existing post
  allowlist — or structurally deceptive per `CamaleonCms::UnsafeMarkup` — adds an error on
  `:content` and the save fails; the admin form re-renders with the message. Nothing is rewritten.
- Trust, opt-out and fail-closed semantics are byte-compatible with the sanitize era: admins and
  roles holding `post_content_unfiltered_html` for the post type save anything;
  `unfiltered_content!` still opts server-side pipelines out; a missing request context still fails
  closed (dangerous content is refused; benign content saves).
- Editing a post whose *stored* content predates the gate stays possible while the content itself
  is untouched — a title fix must not brick an old post.
- New read-only task `rake camaleon_cms:security:scan_content` lists stored post content and gated
  custom-field values that would fail today's gates, for manual cleanup (nothing is modified).
- The theme-DSL helper `ContentSelectHelper#the_content` no longer applies its render-time
  `sanitize` (which used the narrow default allowlist and so also broke trusted authors' tables and
  embeds on that one path): stored content is gated at save and renders verbatim, the same contract
  as the templates' `raw post.the_content`.

## Notes for upgraders

- An untrusted author's save containing disallowed markup now **fails with an error** instead of
  saving with the markup stripped. The author fixes the content or an admin grants
  `post_content_unfiltered_html`.
- Content stored before the gate is not rewritten. Run `rake camaleon_cms:security:scan_content`
  to list what would be refused today and clean it up by hand.
- The gate admits `data-*`/`aria-*` attributes by shape (inert without script); the sanitize-era
  allowlist silently stripped them.

## Out of scope

- Rewriting or quarantining historical content (the scan task reports; the operator decides).
- Comment content (stored unsanitized today) — a separate audit item.
- The cama_contact_form gem's own gate (separate upstream; `CamaleonCms::UnsafeMarkup` is the core
  module it should eventually consume — keep in parity until then).
