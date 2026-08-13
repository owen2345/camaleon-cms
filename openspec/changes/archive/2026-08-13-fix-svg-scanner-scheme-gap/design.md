# Design

## D1. The SVG scanner is the only gate, so it must reach scheme parity

`UploaderContentSecurity#content_unsafe?` routes `.svg` uploads to `SvgContentChecker.unsafe?` and
returns early — the generic `ContentSecurity::SUSPICIOUS_PATTERNS` scan (which carries the gap-tolerant
`BLOCKED_SCHEME_PATTERN`) never runs on an SVG. So a scheme evasion the SVG scanner misses is not
caught by any second layer, and when nginx serves `public/` directly the response headers do not apply
either (same rationale as the M4 fix #1243). The SVG scanner must therefore be no more permissive than
its non-SVG sibling about the same bytes.

## D2. Two representations, both normalized

The payload appears in two forms, and a naive gap regex catches neither reliably:

- `attr.value` for `href="java&#9;script:…"` — Nokogiri **decodes** the char-ref, so the value is
  `"java\tscript:…"` (a literal TAB). A gap-tolerant pattern matches this directly.
- `doc.to_xml` — Nokogiri **re-emits** the TAB as `&#9;`, so the serialized string is
  `"java&#9;script:…"`. A `[\t\n\r]*` gap pattern does **not** match `&#9;` (those are four literal
  characters, not a TAB). It matches only after `ContentSecurity.normalize` entity-decodes it back to a
  TAB — exactly what the non-SVG path already does.

So both checks pass their input through `ContentSecurity.normalize` first and then match
`ContentSecurity::BLOCKED_SCHEME_PATTERN`. `normalize` keeps TAB/LF/CR (the gap characters) and strips
only the control characters a browser ignores, so it neither hides nor invents a scheme.

## D3. Reuse ContentSecurity, don't duplicate the pattern

Matching the shared `BLOCKED_SCHEME_PATTERN` and `normalize` — rather than hand-writing a second
gap-tolerant regex — is what guarantees the two rulesets cannot drift apart again (the drift NEW-1
describes is precisely a second copy that lacked the gap). `content_security` is required before
`svg_content_checker` in `lib/camaleon_cms.rb`, and both live in `CamaleonCms`, so the reference
resolves with no new require. The blocked scheme set is unchanged (`javascript`/`vbscript`/`data`).

## D4. Scope kept tight

- The `href` check drops its `\A` anchor with the switch to the shared (unanchored) pattern. This is
  not a new false-positive surface: the serialized catch-all already scans the whole document
  unanchored for the same schemes, so any file the unanchored href check now flags was already flagged.
- The `<script[\s>]` serialized backstop stays on the raw serialization and unchanged — script
  elements are already caught by the `BANNED_TAGS` XPath; NEW-1 is about schemes only.
- Safe-acceptance behavior is unchanged: a safe SVG whose text merely contains a colon is still
  accepted (no blocked scheme precedes it).

## D5. Testing

`spec/lib/svg_content_checker_spec.rb` adds the gap cases: a TAB gap in a `javascript:` href, the
audit's auto-triggering `<animate begin="0s">` carrier, and a newline-gap scheme in the serialized
catch-all — each `false` (accepted) on master, `true` (rejected) after the fix (stash-verified) — plus
an accepted safe SVG whose text contains a colon, to show the stricter match does not over-block.
