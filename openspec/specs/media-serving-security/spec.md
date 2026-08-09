## Purpose

Define the security requirements for serving SVG media files. SVG files served from `/media/` MUST include security headers that prevent inline script execution in the browser.
## Requirements
### Requirement: SVG responses include X-Content-Type-Options nosniff

The system SHALL set `X-Content-Type-Options: nosniff` on HTTP responses for SVG files served from the `/media/` URL path.

#### Scenario: SVG response has nosniff header
- **WHEN** a browser requests an SVG file at `/media/{site_id}/image.svg`
- **THEN** the response includes the `X-Content-Type-Options: nosniff` header

### Requirement: SVG responses include Content-Security-Policy script-src 'none'

The system SHALL set `Content-Security-Policy: script-src 'none'` on HTTP responses for SVG files served from the `/media/` URL path, blocking JavaScript execution while allowing the SVG to render visually.

#### Scenario: SVG response has CSP script-src 'none' header
- **WHEN** a browser requests an SVG file at `/media/{site_id}/image.svg`
- **THEN** the response includes the `Content-Security-Policy: script-src 'none'` header

### Requirement: Non-SVG media files are unaffected

The system SHALL NOT add the SVG security headers to non-SVG media files served from `/media/`.

#### Scenario: PNG response is unchanged
- **WHEN** a browser requests a PNG file at `/media/{site_id}/image.png`
- **THEN** the response does NOT include `Content-Security-Policy: script-src 'none'`

### Requirement: Header middleware installation does not depend on the host's static file server

The system SHALL install `CamaleonCms::MediaSecurityHeaders` in the middleware stack under both
static-file configurations: before `ActionDispatch::Static` when the host application has
`public_file_server.enabled` set to true, and appended ahead of the engine's own static file
handler when it does not. Application boot SHALL NOT raise when `ActionDispatch::Static` is absent
from the host stack.

#### Scenario: Boot with the public file server disabled

- **WHEN** the host application boots with `config.public_file_server.enabled = false`
  (the standard production configuration behind nginx/Apache)
- **THEN** `Rails.application.initialize!` completes without error
- **AND** `CamaleonCms::MediaSecurityHeaders` is present in the middleware stack

#### Scenario: Headers still precede static serving when the file server is enabled

- **WHEN** the host application boots with `config.public_file_server.enabled = true`
- **THEN** `CamaleonCms::MediaSecurityHeaders` sits before `ActionDispatch::Static`, so SVG
  responses served statically still carry the security headers

### Requirement: SVG path matching is case-insensitive

The system SHALL apply the SVG security headers to `/media/` responses whose path ends in the
`.svg` extension regardless of the extension's case, so an uppercase-extension SVG (`image.SVG`)
served inline is protected exactly as a lowercase one.

#### Scenario: Uppercase-extension SVG response carries the headers

- **WHEN** a browser requests an SVG file at `/media/{site_id}/image.SVG`
- **THEN** the response includes `X-Content-Type-Options: nosniff`
- **AND** the response includes `Content-Security-Policy: script-src 'none'`

### Requirement: Response header keys are Rack 3 compliant

The system SHALL emit the SVG security headers with lowercase header-field names, as required by
the Rack 3 SPEC and enforced by `Rack::Lint` and Falcon.

#### Scenario: Emitted header keys are lowercase

- **WHEN** the middleware adds the SVG security headers to a response
- **THEN** the emitted header keys are `x-content-type-options` and `content-security-policy`
- **AND** no mixed-case variant of those keys is emitted

