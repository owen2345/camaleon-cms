## ADDED Requirements

### Requirement: Untrusted authors' dangerous post tag names are rejected at save time

When a post save submits tag names, each submitted name SHALL be scanned with the shared
unsafe-markup detector under the same allowlist and the same trust gate as post content. For an
author without the unfiltered-content trust, a save containing any dangerous tag name SHALL be
refused with a validation error; names MUST NOT be sanitized, stripped, or otherwise transformed.
Saves that submit no tag names, trusted authors' saves, and previously stored tag names are
unaffected.

#### Scenario: Dangerous tag name refused for an untrusted author

- **WHEN** an untrusted author saves a post whose submitted tags include a name containing
  markup the detector flags (for example `<img src=x onerror=alert(1)>`)
- **THEN** the save is refused with a validation error, no tag is created or associated, and the
  submitted name is stored nowhere

#### Scenario: Plain tag names save normally

- **WHEN** an untrusted author saves a post with ordinary tag names (including multi-word names)
- **THEN** the save succeeds and the names are stored verbatim

#### Scenario: Trusted authors are not gated

- **WHEN** an author with the unfiltered-content trust saves a post with a tag name the detector
  would flag
- **THEN** the save succeeds unchanged, consistent with the content-level trust gate
