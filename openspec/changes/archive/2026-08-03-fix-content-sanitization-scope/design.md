# Design: fix-content-sanitization-scope

## Context

#1206 added `Post#before_validation :sanitize_content` using
`ActionController::Base.helpers.sanitize` with no allowlist argument, i.e. the Rails default
(`Rails::HTML5::SafeListSanitizer` defaults). The audit (H7) confirmed two collateral problems:
the default allowlist has no table/figure elements and drops `id`/`style`/`target`/`rel`, so
untrusted authors lose legitimate structure on every save; and the fail-closed rule sanitizes all
saves without a `CurrentRequest.user`, so developer-controlled pipelines are mutated with no
escape hatch. The security goal — no stored executable content from untrusted authors — is not in
question and is preserved unchanged. H10 (theme activation) ships in the same branch as a
one-line restoration; it has no capability of its own.

## Goals / Non-Goals

**Goals:**

- Stop destroying legitimate structural markup on untrusted post saves.
- Give trusted server-side code an explicit, non-mass-assignable opt-out.
- Keep the executable-content posture byte-for-byte as strict as today.

**Non-Goals:**

- Backfilling `post_content_unfiltered_html` onto existing Editor/custom roles — that is a
  deliberate security default (documented in the capability), and widening the allowlist already
  removes the day-to-day pain (tables/embeds-by-attribute) without granting script capability.
- Allowing `iframe`/`video`/`audio`/`embed` for untrusted authors — those remain admin-only via
  the existing permission; YouTube-style embeds are exactly the trusted-role case.
- Touching `NormalizeAttrs` (descriptions, `NavMenuItem#name`) — their strict defaults are correct
  for short plain-text-ish fields.

## Decisions

- **D1 — Widen the allowlist as a superset of the sanitizer default, not a hand-rolled list:**
  the constants are `Rails::HTML5::SafeListSanitizer.allowed_tags + EXTRA_TAGS` and the attribute
  equivalent, so upstream security fixes to the base list are inherited and we only ever add.
  Rejected: a fixed literal list (drifts from upstream), or switching sanitizer backends
  (needless blast radius).
- **D2 — `style` is allowed but relies on the sanitizer's own CSS scrubber:** loofah/rails-html
  strips `expression()`, `url(javascript:…)`, and behaviour properties from `style` values, so
  allowing the attribute restores inline layout without opening a script vector. The requirement
  states "scrubbed", and a spec asserts a script-bearing style is neutralized while a plain one
  survives.
- **D3 — Opt-out via a reader + `unfiltered_content!` bang enabler with no `=` writer, checked
  first in `sanitize_content`:** a plain `attr_accessor` is in fact mass-assignable at the model
  level — `Post.new(unfiltered_content: true)` would set it, since strong parameters only guard
  the controller. Exposing a reader plus a bang method and no `unfiltered_content=` writer means
  `assign_attributes` has nothing to call, so mass assignment raises `UnknownAttributeError`
  instead of silently flipping a security-sensitive flag. `sanitize_content` returns early when
  the flag is set. Rejected: a plain accessor (mass-assignable, the bug this avoids); a private
  writer (`respond_to?` is false, so mass assignment still raises, but the intent reads less
  clearly than a named bang); a thread/CurrentAttributes flag (leaks across records). Ordering:
  the opt-out check comes before the trust check so it also short-circuits the Ability lookup.
- **D4 — `cama_sanitize_translatable` gains optional `tags:`/`attributes:` keyword args
  defaulting to `nil`:** when nil it behaves exactly as today (sanitizer default), so
  `NormalizeAttrs` and every other caller are untouched; `Post#sanitize_content` passes the
  widened lists explicitly. Keeps the translation-marker hide/restore logic in one place.
- **D5 — H10 restores plain string literals** (the 2.9.2 form) for the two footer field defaults,
  rather than swapping `helper.` for `helpers.`: the values are static HTML, so a literal is
  simplest and removes the controller-context dependency entirely. A feature spec activates the
  bundled theme end-to-end so the hook actually runs.

## Risks / Trade-offs

- [A theme/plugin matching on the exact old sanitized output of untrusted content sees more tags
  now] → the change only *adds* preserved tags; nothing previously stripped-and-relied-upon
  changes, and trusted output was never sanitized. Acceptably low.
- [`style` retention depends on the sanitizer's CSS scrubber being sound] → it is the same
  scrubber the framework ships for all `sanitize` calls; if it has a hole, every Rails app shares
  it. A spec pins the script-in-style case.
- [Opt-out misuse could re-introduce stored XSS if a developer sets it on request-derived
  content] → it is server-only and non-mass-assignable by design; the requirement and a spec
  enforce that params cannot set it.

## Migration Plan

No schema or data migration. Content stripped before this change is not restored (the original
input is gone); authors re-adding tables/embeds simply keep them now. Operators need do nothing.

## Open Questions

None.
