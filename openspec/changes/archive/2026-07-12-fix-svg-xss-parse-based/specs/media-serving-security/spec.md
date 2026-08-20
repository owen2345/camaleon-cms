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
