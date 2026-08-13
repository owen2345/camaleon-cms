# security-capability-gating (delta)

## ADDED Requirements

### Requirement: Untrusted input is rejected, never transformed

When a gate must stop dangerous content submitted by an untrusted user, the remedy SHALL be a
save-time refusal with an error naming the problem. The content SHALL NOT be sanitized, stripped,
escaped-away, or otherwise rewritten, at save or at render: stored content always equals authored
content, and the frontend may emit it verbatim. Output encoding the platform applies by default to
non-markup values (standard ERB escaping) is not a remedy and carries no gate. Content stored
before a gate existed SHALL be reported for operator review (read-only scan), not rewritten. New
proposals that stop dangerous content SHALL conform to this remedy and cite this requirement,
rather than introduce a sanitizing or transforming step.

#### Scenario: A proposal remedies dangerous content with a transform

- **WHEN** a change proposes sanitizing, stripping, or rewriting an untrusted user's content —
  at save or at render — instead of refusing the save
- **THEN** the proposal does not conform to this capability and must be reworked as a rejection

#### Scenario: A conforming gate refuses and preserves

- **WHEN** an untrusted user submits content the gate does not permit
- **THEN** the save fails with an error naming the problem, nothing derived from the content is
  stored, and previously stored content is left exactly as it was

#### Scenario: Historical data is reported, not rewritten

- **WHEN** a new gate ships and stored content predating it would now be refused
- **THEN** the stored content is left untouched and a read-only scan lists it for operator review
