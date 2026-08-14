# Design

## D1. A validation, not a callback

The sanitize era mutated `content` in a `before_validation`. Rejection is a plain validation:
`errors.add(:content, …)` makes `save` return false, and the admin posts controller already
re-renders the form with inline errors on a failed save — no controller changes needed. The
change-guard (`new_record? || content_changed?`), the blank check, the `unfiltered_content`
opt-out, and the lazy trust lookup (Ability built only when there is content to gate) carry over
unchanged from `sanitize_content`.

## D2. Same allowlist, same trust, new remedy

What counts as "dangerous" is unchanged: the widened post allowlist
(`CONTENT_ALLOWED_TAGS`/`CONTENT_ALLOWED_ATTRIBUTES`) — the detector (`UnsafeMarkup.unsafe_html?`)
asks what the safe-list scrubber would remove, so anything the sanitize era would have stripped now
causes a refusal instead. Two deliberate deltas: `data-*`/`aria-*` attributes are admitted by shape
(inert, and silently stripping them was itself a transform), and structurally deceptive markup the
sanitizer was blind to (parser-dropped tags, unterminated tags, translation markers inside tags,
stray comments, oversized values) is refused outright.

## D3. Grandfathered stored content

The gate fires only when content changes. A post stored before the gate remains fully editable in
its other attributes; touching the content itself re-runs the gate. This avoids bricking old posts
while guaranteeing no *new* dangerous content enters. The companion scan task
(`camaleon_cms:security:scan_content`, read-only, TaskReporter output) lists every stored post
content and gated custom-field value that would fail today, so an operator can retire the backlog
deliberately — matching the "scan and reject" model for data that predates the gate.

## D4. No render-time transforms anywhere

The policy removes every transform of authored content, render side included: the theme-DSL helper
`ContentSelectHelper#the_content` sanitized with the *default* allowlist — stricter than the post
allowlist, so an admin's iframe or a contributor's table rendered fine through the normal templates
(`raw post.the_content`) but broke through the DSL path. Both paths now emit stored content
verbatim; the storage gate (plus the scan task for pre-gate data) is the single defense. Messages
the gates emit fall back to English explicitly — only en.yml carries the new keys, and the process
locale follows the current admin/site language (a request-spec locale-leak surfaced this; the suite
now also resets `I18n.locale` per example in `rails_helper`).

## D5. Testing

`spec/models/post_content_rejection_spec.rb` (renamed from `post_content_sanitization_spec.rb`)
rewrites the sanitize-era examples to rejection semantics: every payload that was previously
stripped now refuses the save (stash-verified red against the sanitize-era model); benign content —
including tables, layout attributes, css-styled markup, translation markers, and `!--` lookalikes —
is stored byte-for-byte (a stronger guarantee than the sanitize era's "survives sanitization");
trust, grant, fail-closed, opt-out and no-mass-assignment-writer examples carry over with unchanged
outcomes. The css path deserves a note: the css scrubber normalizes whitespace and trailing
semicolons while it scrubs, so the detector compares style values declaration-by-declaration and
normalizes them on the tree before the serialization comparison — a benign `style="text-align:
center;"` (the default site seed) saves, `expression()` still refuses.
