## Why

The upload content scan picks its ruleset by comparing the filename against the literal string
`.svg`. Everything else falls through to a hand-written denylist of 57 event-handler stems, which
is missing `onpointer*`, `ontouch*`, `onauxclick` and `onemptied`. The same hostile payload is
therefore refused as `x.svg` and accepted as `x.html`, `x.htm`, `x.xhtml`, `x.xml` or `x.svgz` —
verified against `master`. An external reporter found the `onpointerdown` case independently.

Uploads of executable script are worse: `.js`, `.mjs`, `.json` and `.wasm` carrying cookie
exfiltration, a keylogger, an obfuscated `fetch` or a `Function`-constructor payload are all
accepted today. Scanning cannot fix that class — JavaScript has no safe subset and no scannable
structure, so a scanner that cannot reach a verdict has to fail closed instead.

## What Changes

- **Scanner selection follows render behavior, not a literal `.svg` match.** Every extension a
  browser parses as markup (`svg svgz svg.gz html htm xhtml xht shtml xml xsl xslt`) is routed to
  the parse-based checker that rejects any `on*` attribute by shape, so no handler name is ever
  named in a list. Extensions that are not served as markup keep the generic scan as
  defense-in-depth.
- **The markup checker gains an HTML parse mode.** `Nokogiri::XML` never sees an HTML document and
  `Nokogiri::HTML` never raises, so the XML branch keeps parse failure as a fail-closed signal
  while the HTML branch cannot and must not.
- **Compressed SVG is decompressed before scanning.** Gzipped bytes are opaque to every rule, so
  `.svgz`/`.svg.gz` is scanned today in name only. Decompression is bounded against expansion
  bombs, and content that is not actually gzip is scanned as raw markup rather than skipped.
- **Script-type uploads require `media_unfiltered_upload`.** `js mjs cjs wasm swf` are refused for
  users without it and unchanged for users with it (they already skip scanning entirely, so this
  grants nothing new). **BREAKING** for untrusted roles that upload script today.
- **A report-only Rake task lists already-stored uploads the new rules would refuse**, following
  the precedent of `lib/tasks/unsafe_stored_content.rake`. The new rules apply at upload time, so
  files already under `public/media/` are otherwise never re-examined.
- **The governing security rule is amended** in `AGENTS.md`, `docs/security/permissions.md` and the
  `security-capability-gating` spec, which today underdetermine two joints: that the save-time
  decision is the only lever (nothing downstream constrains stored content), and that a permission
  gate ranks below scanning (valid only where no scan can decide). Both gaps admitted proposals
  during this change's own planning that had to be withdrawn.

Non-goals: no server-enforced extension allowlist, and no change to which file types may be
uploaded beyond the script gate above. Untrusted uploads continue to be scanned and rejected on
finding something dangerous, never sanitized or rewritten. Nothing downstream of the save-time
decision is constrained: stored content is served verbatim, and no serving-side header, policy or
disposition is added — content a trusted user was permitted to store must run in the browser
exactly as they intended. Archive-borne malware (`.zip`, `.docx`) is a distribution concern, not
origin XSS, and stays out of scope.

## Capabilities

### New Capabilities

None. Every requirement lands in an existing capability.

### Modified Capabilities

- `upload-content-security`: ruleset selection becomes a function of how the stored file will be
  rendered rather than an `.svg` string match; compressed markup is decompressed before scanning;
  script-type extensions are refused for untrusted uploaders; a report-only backfill scan of
  already-stored uploads is specified.
- `svg-upload-sanitization`: the parse-based checker's scope widens from SVG to every markup
  extension, and gains a second parse mode for HTML, where parse failure is not available as a
  signal. The capability path is preserved for continuity even though its subject is now broader
  than SVG.
- `unfiltered-upload-permission`: `media_unfiltered_upload` additionally authorizes uploading
  executable script types, which are refused without it.
- `security-capability-gating`: the remedy rule gains its lower bound — the save-time decision is
  the only lever, and no serving-side control may constrain stored content — and the gating rule
  gains its precedence — a permission gate is the last resort, valid only where no scan can reach a
  verdict, and an existing permission is extended rather than replaced.

## Impact

- `lib/camaleon_cms/svg_content_checker.rb` — widened to markup, two parse modes.
- `lib/camaleon_cms/uploader_content_security.rb` — extension classification and routing,
  decompression, script-type refusal.
- `lib/camaleon_cms/content_security.rb` — the event-handler denylist stops being load-bearing for
  markup and remains defense-in-depth elsewhere.
- `lib/tasks/` — new report-only scan task.
- Ruby stdlib `zlib` for bounded decompression. No new gem dependencies.
- Downstream: a role without `media_unfiltered_upload` that uploads `.js` today starts being
  refused. Needs a CHANGELOG upgrader note naming the permission to grant. Markup uploads that
  succeed today are unaffected — `<script>`, `<iframe>`, `<meta>`, `<style>`, `<link>`, `<base>`
  and `<form>` are already refused by the existing element denylist, so the markup change only
  adds refusals for content the current policy already intends to reject.
