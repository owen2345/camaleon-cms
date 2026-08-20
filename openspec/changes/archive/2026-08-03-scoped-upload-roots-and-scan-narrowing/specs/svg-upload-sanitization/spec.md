## MODIFIED Requirements

### Requirement: Safe SVGs are accepted

The system SHALL accept SVG uploads that contain no dangerous elements, attributes, or URIs.

The SMIL animation elements `animate` and `set` SHALL be treated as safe elements: they carry no script by themselves, and the scripting risk they were associated with is the `onbegin`/`onend`/`onrepeat` event-handler attributes, which the event-handler rule continues to reject independently of the element they appear on. Elements that embed foreign content or handlers — `script`, `foreignObject`, `handler`, `iframe`, `object`, `embed` — remain rejected.

#### Scenario: Safe SVG without dangerous content is accepted
- **WHEN** a user uploads an SVG file with no script elements, event handlers, or javascript: URIs
- **THEN** the system stores the file normally

#### Scenario: Animated SVG without event handlers is accepted
- **WHEN** a user uploads an SVG containing `<circle><animate attributeName="r" values="1;2" dur="1s"/></circle>` and no event-handler attributes
- **THEN** the system stores the file normally

#### Scenario: A `set` element without event handlers is accepted
- **WHEN** a user uploads an SVG containing `<set attributeName="fill" to="blue"/>` and no event-handler attributes
- **THEN** the system stores the file normally

#### Scenario: An animation element carrying an event handler is still rejected
- **WHEN** a user uploads an SVG containing `<animate onbegin="alert(1)"/>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: foreignObject remains rejected
- **WHEN** a user uploads an SVG containing a `<foreignObject>` element
- **THEN** the system returns an error and does NOT store the file
