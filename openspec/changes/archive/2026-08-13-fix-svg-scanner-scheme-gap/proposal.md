## Why

`SvgContentChecker.unsafe?` is the only malicious-content gate for an uploaded SVG — the generic
scanner is skipped for `.svg`. #1226 left its two scheme checks (`href`/`xlink:href` and the serialized
catch-all) matching URI schemes with **no gap tolerance**, unlike
`ContentSecurity::BLOCKED_SCHEME_PATTERN`, which deliberately allows TAB/LF/CR between scheme
characters. A browser strips those characters before executing a URI, so `java&#9;script:` in an
`xlink:href` is live markup the SVG scanner accepted; with `<animate begin="0s">` it is auto-triggering
stored XSS. Reachable by any uploader holding `:manage, :media` that lacks `media_unfiltered_upload`.
Audit finding NEW-1.

### Triage verdict: legit

Reproduced in `spec/lib/svg_content_checker_spec.rb`: on master `unsafe?` returns `false` for a
`java&#9;script:` href, the animated auto-trigger, and a newline-gap catch-all — all fail without the
fix. Confidence is bounded by the browser question (current Chrome restricts SMIL-animated
`javascript:`), but the scanner is the only gate when nginx serves `public/` directly, so parity is
warranted regardless.

## What Changes

- Both scheme checks in `SvgContentChecker.unsafe?` now reuse `ContentSecurity::BLOCKED_SCHEME_PATTERN`
  (gap-tolerant) and `ContentSecurity.normalize` (entity/control-char decoding): the decoded `href`
  value and the entity-decoded serialized document are matched against the shared pattern.
- A TAB/LF/CR gap inside a scheme (`java&#9;script:`) is now rejected in an SVG exactly as it already
  is in every non-SVG upload — the two rulesets stop disagreeing about the same bytes. The blocked
  scheme set (`javascript`/`vbscript`/`data`) is unchanged.

## Notes for upgraders

- An SVG carrying a gap-obfuscated blocked scheme (previously accepted by the narrowed scanner) is now
  rejected on upload. Legitimate SVGs are unaffected.

## Out of scope

- Whether a given browser still executes a SMIL-animated gap `javascript:` href — the fix is
  defense-in-depth parity, independent of that. The click-triggered href gap predates #1226 and is
  closed by the same change.
- The `<script[\s>]` serialized backstop and the `BANNED_TAGS` element check are unchanged.
