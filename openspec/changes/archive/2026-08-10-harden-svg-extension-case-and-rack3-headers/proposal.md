## Why

Regression-audit lows L5 and L6 (post-2.9.2 review), both in the SVG-serving defense-in-depth path:

- **L5** — the upload content scanner and the response-header middleware both matched the `.svg`
  extension case-sensitively (`end_with?('.svg')`, `%r{...\.svg\z}`). An `evil.SVG` (uppercase, or
  any mixed case) is a first-class upload — `get_file_format` downcases the extension, so it is
  classified as an image, stored, and served verbatim. Two gaps followed: at scan time the file
  bypassed the SVG-specific parser (`SvgContentChecker`) and fell through to the weaker generic
  denylist, which does not list SVG-only vectors such as `foreignObject`/`handler`; at serve time
  the `/media/*.svg` header middleware did not match the uppercase path, so the SVG was served
  inline without `X-Content-Type-Options: nosniff` or `Content-Security-Policy: script-src 'none'`.
- **L6** — `MediaSecurityHeaders` set mixed-case header keys (`X-Content-Type-Options`,
  `Content-Security-Policy`). The Rack 3 SPEC requires lowercase keys; Rack::Lint and Falcon reject
  mixed case (Puma tolerated it, which hid the defect). The project runs Rack 3.

## What Changes

- **L5**: the `.svg` extension test is now case-insensitive in both places. `content_unsafe?` and
  `svg_upload?` route on `File.extname(name).casecmp?('.svg')`, so any-case SVG uploads reach the
  SVG parser; `MediaSecurityHeaders::SVG_PATH_PATTERN` gains the `i` flag, so any-case SVG paths
  under `/media/` carry the protective headers.
- **L6**: `MediaSecurityHeaders` emits lowercase header keys.

## Capabilities

### Modified Capabilities

- `upload-content-security`: SVG detection at scan time is case-insensitive, so an uppercase-extension
  SVG is routed to the SVG parser rather than the generic scan.
- `media-serving-security`: the header middleware matches SVG paths case-insensitively and emits
  Rack-3-compliant lowercase header keys.

### New Capabilities

None.

## Impact

- `lib/camaleon_cms/uploader_content_security.rb` (case-insensitive `.svg` seam),
  `lib/camaleon_cms/media_security_headers.rb` (case-insensitive path + lowercase header keys).
- Specs: `spec/lib/camaleon_cms/uploader_content_security_spec.rb` (uppercase `.SVG` routing),
  new `spec/lib/camaleon_cms/media_security_headers_spec.rb` (header-key casing, unit),
  `spec/requests/media_security_headers_spec.rb` (uppercase `.SVG` served inline).
- No routes or schema changes. Behavior delta: uppercase-extension SVG uploads are scanned as SVGs
  and served with the same headers as lowercase ones; response header keys are lowercase.
