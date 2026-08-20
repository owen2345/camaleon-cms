## Why

The SVG upload content scanner uses a regex-based denylist on raw file bytes. This is bypassed by: (1) HTML entity encoding of dangerous strings (e.g., `javascript&#58;`), (2) XML DTD entity substitution to inject arbitrary content, and (3) missing event handler attributes (`onpointerdown`, `onanimationend`, etc.). The concatenation bug `onunloadonsubmit` also causes `onunload` and `onsubmit` to be missing. Additionally, uploaded SVGs are served from `public/media/` as static files with no security headers, allowing stored XSS in the site origin when a user opens the file.

## What Changes

- Replace the regex-based content scanning for SVG uploads with Nokogiri XML parse-based detection that rejects dangerous SVGs before storage — parse resolves all entities, check for dangerous elements/attributes, reject if found
- Add a Rack middleware that intercepts SVG responses under `/media/` and adds `X-Content-Type-Options: nosniff` and `Content-Security-Policy: script-src 'none'` headers, preventing script execution even if a malicious SVG is served
- Remove the now-redundant regex-based `SUSPICIOUS_PATTERNS` for SVG files (retain for non-SVG files as a safety net)
- Remove the `UNSAFE_EVENT_PATTERNS` list (replaced by parse-based detection)

## Capabilities

### New Capabilities

- `svg-upload-sanitization`: SVG upload content security — the system MUST parse uploaded SVG files with an XML parser, resolve all entities, and reject the upload if dangerous elements (script, etc.) or attributes (event handlers, javascript: URIs) are present. Safe SVGs without dangerous content are accepted.
- `media-serving-security`: SVG response security headers — the system MUST serve SVG media files with `X-Content-Type-Options: nosniff` and `Content-Security-Policy: script-src 'none'` headers to prevent inline script execution in the browser.

### Modified Capabilities

- `upload-content-security`: The `file_content_unsafe?` method no longer scans SVG files using the regex denylist — SVG content checks are handled by the parse-based pipeline that rejects dangerous files before storage. The regex scanning is retained for non-SVG file types.

## Impact

- `lib/camaleon_cms/content_security.rb` — the `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` constants are no longer needed for SVG scanning (consider removal or deprecation)
- `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` — add SVG parse-based content check that rejects dangerous uploads before storage
- `app/helpers/camaleon_cms/uploader_helper.rb` — same change in duplicated implementation
- `lib/camaleon_cms/engine.rb` — register the Rack middleware for SVG security headers
- New middleware file (e.g., `lib/camaleon_cms/media_security_headers.rb`)
- `spec/support/fixtures/` — add test SVG fixtures for entity encoding, DTD entities, missing event handlers
- `spec/helpers/uploader_helper_spec.rb` — update tests for parse-based SVG content checking
- Add request spec for middleware SVG headers
