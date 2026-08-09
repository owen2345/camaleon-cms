## ADDED Requirements

### Requirement: SVG detection at scan time is case-insensitive

The content scanner SHALL treat an upload whose filename extension is `.svg` in any case as an SVG,
routing it to the SVG-specific parser (`SvgContentChecker`) rather than the generic denylist scan.
An uppercase-extension SVG (`evil.SVG`) therefore cannot reach the weaker generic ruleset that does
not list SVG-only vectors such as `foreignObject`.

#### Scenario: Uppercase-extension SVG is routed to the SVG parser

- **WHEN** `content_unsafe?` is called with a filename ending in `.SVG` (or any other case)
- **THEN** the content is evaluated by the SVG parser, not the generic pattern scan

#### Scenario: An SVG-only vector is rejected regardless of extension case

- **WHEN** an SVG carrying a `foreignObject` element is scanned as `image.svg` and as `image.SVG`
- **THEN** both are rejected as unsafe
