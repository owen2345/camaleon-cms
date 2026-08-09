## ADDED Requirements

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
