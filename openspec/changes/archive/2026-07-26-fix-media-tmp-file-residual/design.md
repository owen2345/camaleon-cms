## Context

`cama_tmp_upload` stages every non-filesystem upload into `public/tmp/<site_id>/` before `upload_file` validates it and moves it into the media library. Three properties of that staging step combine into the problems this change addresses:

1. The staging directory lives under `Rails.public_path` and is therefore served statically.
2. Content scanning (`file_content_unsafe?`) runs in `upload_file` — *after* the staging write. On rejection `upload_file` returns at its guard clause, before the `FileUtils.rm_f(uploaded_io.path)` cleanup near the end of the method.
3. Nothing bounds the size of a `data:` payload before it is decoded and written.

Current flow, with both gaps marked:

```
POST /admin/media/actions  media_action=crop_url  name=x.html
  │  url = data:...;base64,<html><script>…</script></html>
  ▼
cama_tmp_upload()
  ├─ File.basename(name)                       ← traversal guard (already fixed)
  ├─ path_within?(path, tmp_path)              ← traversal guard (already fixed)
  ├─ (no size bound)                           ◀── GAP 2: unbounded decode + write
  └─ File.open(path,'wb'){ write(decoded) }    ── staged on a served path, unscanned
  ▼
upload_file()
  ├─ cama_canonical_upload_path(io)
  ├─ file_content_unsafe?(io) → true           ── first scan happens here, too late
  └─ return { error: 'Potentially malicious content found!' }   ◀── GAP 1: NEVER CLEANS UP
       │
       └─ public/tmp/1/x.html survives indefinitely ──► GET /tmp/1/x.html ──► script executes
```

Both `RuntimeUploaderConcern` and `UploaderHelper` carry near-identical copies of `cama_tmp_upload` and `upload_file`. Recent security work (`UploaderPathSecurity`, `UploaderContentSecurity`) has consistently extracted shared guards into `lib/camaleon_cms/` modules included by both, precisely so fixes cannot drift. This change follows that precedent.

## Goals / Non-Goals

**Goals:**
- Hostile bytes never reach a web-served path, even transiently.
- Oversized payloads are rejected before they are decoded or written.
- A failed upload — for any reason — leaves nothing behind in the staging directory.
- Cleanup can never delete a file outside the staging root.
- The content denylist rejects the encoding, scheme, and element bypasses confirmed against the current patterns.
- Fixes land identically in `RuntimeUploaderConcern` and `UploaderHelper`.

**Non-Goals:**
- Widening `MediaSecurityHeaders` beyond SVG (Decision 5).
- Replacing the denylist with an extension allowlist (Decision 6).
- Relocating staging out of `public/` (Decision 6).
- Garbage-collecting staging files orphaned by earlier releases or by a process crash mid-upload.
- Any change to the traversal guards, which are already correct.

## Decisions

### Decision 1: Scan content before the staging write

Move the content-security check ahead of the `File.open(path, 'wb')` write in `cama_tmp_upload`'s `data:` branch, and ahead of the staging write for downloaded remote bodies. This closes the exposure completely rather than narrowing it.

This was initially rejected on the grounds that holding the decoded payload in memory to scan it would raise peak memory on large `data:` uploads. Measurement showed the opposite. At the moment of the write, for an 8 MB payload:

| Live object | Size |
|---|---|
| `data_uri` (the request parameter) | 10.7 MB |
| `split(';base64,')` copy | 10.7 MB |
| `Base64.decode64` result | 8.0 MB |
| **peak, before any scan exists** | **29.4 MB** |

`Base64.decode64` already returns the complete decoded String; today it is passed inline to `f.write`. Scanning that same String costs **zero additional copies** and ~4.4 ms for an 8 MB input. Moreover the current path materializes the content a *second* time regardless: `upload_file` → `file_content_unsafe?` → `file.read`, after a disk round-trip. For the rejection case, scanning before the write makes that second copy unnecessary. Pre-scanning is memory-neutral at worst and cheaper on rejection.

The genuine unbounded-memory problem is the staging write itself, which exists today independently of scanning — addressed by Decision 2.

This requires a scanner entry point that accepts content rather than a file handle. `UploaderContentSecurity` currently exposes only `file_content_unsafe?(uploaded_io)`, which reads from an IO. Add `content_unsafe?(content, filename:)` holding the actual logic (SVG → `SvgContentChecker`, otherwise → normalized pattern matching), and reduce `file_content_unsafe?` to a wrapper that reads the IO, rewinds it, and delegates. One scanner, two entry points — no second denylist to drift.

*Alternative considered:* rely solely on cleanup (Decision 3). Rejected — cleanup alone leaves the bytes on a served path for the duration of the scan, so an attacker polling the URL on a parallel connection while their own upload is in flight can still retrieve them. That converts a reliable exposure into a race, not into a fix.

### Decision 2: Bound the payload before decoding it

Reject an oversized `data:` upload before `Base64.decode64` runs, by estimating decoded size from the base64 length (`bytesize * 3 / 4`). The estimate is an upper bound accurate to within two bytes, and errs toward rejecting slightly early — the safe direction for a guard.

Also default `args[:maximum]` to `current_site.get_option('filesystem_max_size', 100).to_f.megabytes` rather than leaving it nil. The existing size check at `cama_tmp_upload` is gated on `args[:maximum].present?`, and neither `crop` nor `crop_url` passes `:maximum`, so it is currently dead code on every media controller path. Defaulting it revives that check as well as feeding the new pre-decode guard.

This is not a new limit — `filesystem_max_size` is already the documented, intended bound, enforced in `upload_file`. The change is enforcing it *before* the write instead of after. The remote-download branch already does exactly this (`cama_download_remote_file` checks `max_bytes` before writing its tempfile); the `data:` branch is being brought in line with it.

*Alternative considered:* decode first, then check actual size. Rejected — it defeats the purpose, since the decode is the allocation being guarded against.

### Decision 3: Cleanup on failure via a guarded shared helper

Decisions 1 and 2 close the content and size cases before anything is written. Cleanup is still required, because some errors are only detectable after staging — `upload_file`'s invalid-folder check runs against the final destination, and the format check runs against the resolved path. It also protects any error path added later by someone unaware of this history.

Implement as a helper in `UploaderPathSecurity` — already included by both copies, already the home of `path_within?`. The helper deletes a path only after confirming via `path_within?` that it lies inside the staging root, so a bug in the calling code can never turn into deletion elsewhere on the filesystem.

Two placement details matter:

- **`cama_tmp_upload` must not clean up on success.** The staged path is the method's return value and the caller consumes it. Cleanup therefore keys off whether the method is returning an error, not off `ensure` unconditionally. The method already has an `ensure` (`downloaded_tmp_file&.close!`), which is the natural place to extend, but it needs an explicit "did we return an error" flag rather than blanket deletion.
- **`upload_file` must clean up only sources it owns.** Its early returns should remove the source only when `remove_source` is set — exactly the flag the controller sets for `crop_url`, the path that stages into `public/tmp/`. When `remove_source` is false the caller owns the file and deleting it would be wrong.

*Alternative considered:* have the controller clean up. Rejected — it puts the obligation on every caller, including third-party plugins that call `cama_tmp_upload` directly.

### Decision 4: Complete the denylist by normalizing before matching

The current `SUSPICIOUS_PATTERNS` match raw bytes. Twelve bypasses were confirmed empirically against them:

| Class | Confirmed bypass |
|---|---|
| Encoding | `jav&#x61;script:` (hex entity) |
| Encoding | `&#106;avascript:` (decimal entity) |
| Encoding | `jav<TAB>ascript:` |
| Encoding | `java<LF>script:` |
| Encoding | `java<NUL>script:` |
| Delimiter | `<script/src="…">` — `/<script[\s>]/` requires whitespace or `>` |
| Scheme | `vbscript:` — absent from the list |
| Element | `<meta http-equiv="refresh">` |
| Element | `<style>@import "…"` |
| Element | `<form action="…">` |
| Element | `<applet code="…">` |
| Element | `<frameset><frame src="…">` |

Adding one pattern per bypass would leave the next encoding variant open. Instead, normalize the content once before matching:

1. Decode HTML entities in a bounded loop, breaking when stable, to catch double-encoding.
2. Strip NUL and C0/C1 control characters.
3. Strip whitespace injected inside a URI scheme.

then match against a widened pattern set: `[\s/>]` as the tag delimiter, `(javascript|vbscript|data)\s*:` for schemes, and the missing elements added to the tag list. This closes the whole encoding class structurally and leaves only genuinely new element or scheme names as future additions.

A prototype of exactly this normalization plus pattern set blocks all twelve confirmed bypasses and leaves plain text, CSV, and JSON fixtures untouched.

**Use 5 passes with break-when-stable**, matching the existing bounded decode loop in `UserUrlValidator#validate_path_traversal` introduced by [PR #1203](https://github.com/owen2345/camaleon-cms/pull/1203). That loop is a *different* decoder — it percent-decodes a URL path (`%252e%252e`) and never touches file content, so it does not address the entity-encoding bypasses here — but its shape is the established in-repo precedent for bounded repeated decoding, and matching its bound keeps the two reading as the same idea rather than two arbitrary numbers.

`SvgContentChecker` already treats `vbscript:` as dangerous while the regex list does not — aligning the two removes an inconsistency where an SVG payload is caught but the identical bytes in an `.html` file are not.

*Alternative considered:* parse non-SVG uploads with an HTML parser, mirroring the SVG approach. Rejected for this change — the scanner runs on arbitrary binary uploads (images, video, archives), not just markup, so there is no meaningful parse tree for most inputs, and forcing one would be both slow and unsound.

### Decision 4b: Entity-decode only, do not percent-decode content

`UserUrlValidator` percent-decodes (`Addressable::URI.unencode`) and `ContentSecurity` entity-decodes (`CGI.unescapeHTML`). The asymmetry is deliberate, not an oversight, and was reviewed explicitly.

Each decoder matches its input. The validator's input is a URL that gets parsed, resolved, and fetched, where `%252e%252e` really does resolve to `..`. The scanner's input is file content a browser parses as markup, where `&#x61;` really does become `a` inside an attribute value but a percent-escape does not: per the URL spec the scheme is matched literally, so `%6Aavascript:` and `javascript%3Aalert(1)` are not schemes at all and never execute — including inside `<meta http-equiv="refresh">`.

Verified there is no double-decode sink that could resurrect a percent-encoded payload: `CGI.unescape` and `Addressable::URI.unencode` occur only in `UserUrlValidator`, both on URLs. Camaleon never percent-decodes uploaded content.

Adding percent-decoding would therefore buy no coverage while rejecting legitimate files that merely contain encoded URLs — JSON exports, CSVs of links, access logs, HAR captures. Rejected. The reasoning is mirrored as a comment on `ContentSecurity.normalize`.

### Decision 4c: Duplication between the two uploader copies stays, for now

`RuntimeUploaderConcern` and `UploaderHelper` hold ~200 duplicated lines (`cama_tmp_upload` 98 lines in both, `upload_file` 82 vs 90). Collapsing them into one module exposed via `helper_method` was considered and does not work:

- `config/initializers/custom_initializers.rb` documents host apps doing `include CamaleonCms::UploaderHelper` inside an ActiveJob. `helper_method` exposes controller methods to views only, so that documented pattern would break.
- The two target different execution contexts by design. The concern depends on `params[:name]` and `helpers.number_to_human_size`, neither of which exists in a job; `UploaderHelper` is self-contained (includes `NumberHelper` and `CamaleonHelper`) and is instantiated standalone in specs.
- Plugins may include it as well — unenumerable, per Decision 6.

They are two entry points for two contexts, not redundant copies. The workable direction is the one already in motion: push shared logic down into `lib/camaleon_cms/` modules both include, as `UploaderPathSecurity` and `UploaderContentSecurity` already do. That extraction needs its own module-boundary design and a seam for the `params` / `ct` / `helpers` differences, so it is deferred to a separate change rather than improvised inside a security fix where it would enlarge the diff and complicate backporting to 2.9.x.

Applied here: `cama_upload_failure` (identical in both) moved into `UploaderPathSecurity`. `cama_size_limit_error` is deliberately NOT shared — the helper translates via `ct`, which runs the `on_translation` hook so plugins can override the message, and a shared `I18n.t` call would silently drop it.

### Decision 5: Leave `MediaSecurityHeaders` scoped to SVG

Widening the middleware to send `nosniff` and `script-src 'none'` on all `/media/` and `/tmp/` responses was considered. **Rejected by the maintainer:** `Content-Security-Policy` on every `/media/` response would break host applications that intentionally serve active content from the media directory.

Consequence: an uploaded `.html` that passes the denylist is served from `/media/` as active content with no mitigating headers. The `media-serving-security` capability is untouched by this change, and its existing requirement that non-SVG media files are unaffected still holds. This raises the stakes on Decision 4 — the denylist is the only layer deciding whether such a file is accepted in the first place.

### Decision 6: Keep the denylist, and keep staging under `public/`

Two structural alternatives were considered and rejected by the maintainer:

- **Extension allowlist instead of a content denylist.** Rejected: it changes which uploads are accepted, with a wide blast radius across host apps, themes, and plugins. Completing the denylist (Decision 4) is the chosen path.
- **Relocating staging to `Dir.tmpdir`.** `cama_canonical_upload_path` already accepts `Dir.tmpdir`, so the guards would not need changing, and nothing inside this repository builds a URL from the staging path. Rejected: `cama_tmp_upload` is a documented public helper whose advertised return value is a `public/tmp/` path, and themes or plugins in the wild may rely on the staged file being reachable by URL (for example to show a crop preview before the final save). Changing it would break them silently.

## Risks / Trade-offs

- **Cleanup deletes a file the caller still needs** → the helper deletes only inside the staging root, only on error returns, and only when `remove_source` is set in `upload_file`. An explicit regression spec asserts the success path leaves the staged file present and readable.
- **Normalization causes false positives** → confirmed: a document containing HTML-escaped code examples (`<p>Use &lt;script&gt; carefully</p>`) decodes to `<script` and is rejected. This is fail-closed and accepted; a spec pins it as intended behavior so it is not "fixed" later by someone reading it as a bug. Operators needing to host such documents must place them outside the upload pipeline.
- **Activating `filesystem_max_size` on the `data:` branch rejects uploads that previously succeeded** → this restores the documented intended limit rather than adding a new one, but it is a visible behavior change for any site relying on the gap. Called out in the changelog.
- **The base64 size estimate is an upper bound** → a payload padded with characters `Base64.decode64` would discard could be rejected marginally early. Negligible in practice, and the conservative direction.
- **Entity decoding on large uploads costs CPU** → normalization runs on content already in memory, so it adds passes but no new read. The 5-pass bound prevents a decoding bomb.
- **The two copies drift again** → all fixes go into shared modules under `lib/camaleon_cms/`; specs exercise the controller path (`RuntimeUploaderConcern`) plus a direct check of the `UploaderHelper` copy.
- **The denylist is still a denylist** → Decision 4 closes a class of bypasses and twelve concrete instances, not the category. A novel dangerous element or scheme will still pass until added. With Decision 5 in place there is no second layer behind it.

## Migration Plan

No data migration, no schema change, no configuration change required of host apps.

Deploy note: files already orphaned in `public/tmp/` from before this fix are not removed by it. Operators should clear `public/tmp/` once on upgrade — worth a changelog line, since on a long-running 2.9.2 install that directory may already hold planted payloads.

Rollback is a straight revert; nothing persists state that would outlive it.

## Resolved Questions

**Credit for the report.** The changelog entry credits Lukman Azri. The finding is not his, but it came directly out of triaging his v2.9.2 RCE report, and the project's changelog convention already credits reporters by name. Note that the reply sent to him deliberately did not mention this residual, since it was unfixed at the time — the credit lands with the fix, not before it.

**Does anything build a URL from the `public/tmp` staging path?** Traced and answered: **no bundled code does, and it cannot be answered for the ecosystem.**

- In-repo: `grep` over `app/apps/themes/` and `app/apps/plugins/` finds no reference to `tmp` at all. The four bundled plugins (`attack`, `authoring_post`, `front_cache`, `visibility_post`) and three bundled themes are clean.
- Out of repo: the overwhelming majority of Camaleon plugins and themes ship as separate gems added to the host app's `Gemfile` — README.md lists roughly two dozen, and that list is not exhaustive. Several are upload- or editor-adjacent (`camaleon_editor`, `Camaleon-Tinymce-Templates`, `CamaImageLightbox`, `camaleon_image_optimizer`) and are exactly the kind of code that would plausibly display a staged file by URL before a final save. The maintainer confirms this is not known either way.

This **confirms the Decision 6 constraint rather than relaxing it.** A clean in-repo trace is not evidence of safety when the contract is public and the consumers are unenumerable: `cama_tmp_upload` advertises a `public/tmp/` return path in its own documentation, so relocating it would be a silent breaking change for an unknown number of downstream gems. Relocation stays out of scope, and would need a deprecation cycle rather than a straight move if ever revisited.

The corollary matters for this change too: the success-path return contract must be preserved exactly, which is why Decision 3 forbids cleanup on success and why a regression spec pins it.
