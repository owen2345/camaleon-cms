## Why

The SVG content security filter introduced in v2.8.2 (GHSA-r9cr-qmfw-pmrc) is missing three SVG animation event handlers — `onbegin`, `onend`, and `onrepeat` — from its blocklist, allowing an attacker to upload a crafted SVG that executes JavaScript when viewed. The event handler blocklist is also duplicated across two files, creating a maintenance hazard where future additions must be made in two places.

## What Changes

- Add `onbegin`, `onend`, and `onrepeat` to the `UNSAFE_EVENT_PATTERNS` array in both locations where it is defined.
- Extract the shared `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` into a single module to eliminate the duplication.
- Add a test fixture SVG using `onbegin` and a corresponding test case.
- Verify all existing tests still pass.

## Capabilities

### New Capabilities

- `upload-content-security`: Safe file uploads — the system MUST reject files containing executable content patterns (event handler attributes, script tags, javascript: URIs, etc.) before storing them. This replaces the ad-hoc inline filter with a testable specification.

### Modified Capabilities

- (none)

## Impact

- `app/helpers/camaleon_cms/uploader_helper.rb` — remove inline `UNSAFE_EVENT_PATTERNS` / `SUSPICIOUS_PATTERNS`, include shared module
- `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` — remove inline `UNSAFE_EVENT_PATTERNS` / `SUSPICIOUS_PATTERNS`, include shared module
- New shared module file (e.g., `lib/camaleon_cms/content_security_scanner.rb` or similar)
- `spec/support/fixtures/` — add test SVG with `onbegin` payload
- `spec/helpers/uploader_helper_spec.rb` — add test case for animation event handlers
