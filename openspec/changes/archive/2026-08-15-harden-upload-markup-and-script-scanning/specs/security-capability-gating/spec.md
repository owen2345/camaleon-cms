## MODIFIED Requirements

### Requirement: Untrusted input is rejected, never transformed

When a gate must stop dangerous content submitted by an untrusted user, the remedy SHALL be a
save-time refusal with an error naming the problem. The content SHALL NOT be sanitized, stripped,
escaped-away, or otherwise rewritten, at save or at render: stored content always equals authored
content, and the frontend may emit it verbatim. Output encoding the platform applies by default to
non-markup values (standard ERB escaping) is not a remedy and carries no gate. Content stored
before a gate existed SHALL be reported for operator review (read-only scan), not rewritten. New
proposals that stop dangerous content SHALL conform to this remedy and cite this requirement,
rather than introduce a sanitizing or transforming step.

The save-time decision SHALL be the only lever. Content that passes a gate is stored **and served**
verbatim: no response header, content-security policy, `X-Content-Type-Options`,
`Content-Disposition`, separate media origin, or other serving-side control SHALL be introduced to
constrain what stored content does in the browser. A trusted user was permitted to store it, so it
SHALL behave exactly as that user intended. This bounds the remedy rule from below in the same way
the no-transform clause bounds it from above: a control that constrains a **trusted** user's content
is outside this capability regardless of its merit as general security hygiene.

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

#### Scenario: A proposal adds a serving-side control over stored content

- **WHEN** a change proposes a response header, CSP, content-disposition or separate origin to
  constrain what already-stored content does in the browser
- **THEN** the proposal does not conform to this capability, because the control acts after the
  save-time decision and applies to trusted users' content as well

#### Scenario: A control is tested against trusted content

- **WHEN** a proposed control is evaluated for conformance
- **THEN** it conforms only if it leaves content a trusted user was permitted to store behaving
  exactly as that user intended

### Requirement: New security-sensitive capabilities conform to this rule
When a change introduces an action or method that presents a security threat to non-administrator
roles, it SHALL gate it per this capability and SHALL cite this capability. It SHALL NOT ship the
action ungated, gate it by a non-authorization proxy, or let the check fail open.

A permission gate SHALL be the last resort, not the first. Where the threat is **content** and that
content can be judged, the save-time scan SHALL judge it; a blanket refusal by file type, format or
category SHALL NOT be introduced in its place. A dedicated permission is the remedy only where no
scan can reach a verdict at all — where the input has no safe subset and no static rule can decide
it — and there the check SHALL fail closed.

Where an existing permission's holders already possess the capability being gated, a change SHALL
extend that permission rather than introduce a new one, because a new permission would revoke the
capability from installs that already granted the existing one.

#### Scenario: A proposal adds a dangerous action
- **WHEN** a proposal introduces a security-sensitive action available to non-administrators
- **THEN** it SHALL add a default-off, fail-closed permission gating it and reference this capability

#### Scenario: A proposal gates by a proxy signal
- **WHEN** a proposal would gate such an action by a path, filename, or client flag
- **THEN** it SHALL be revised to gate on the acting user's permission instead

#### Scenario: A proposal gates content a scan could judge
- **WHEN** a proposal would refuse a whole content format by permission, and that format has a
  grammar a scan can evaluate (for example uploaded markup)
- **THEN** it SHALL be revised to let the save-time scan decide, leaving the format ungated

#### Scenario: A proposal gates content no scan can judge
- **WHEN** a proposal would refuse content for which no scan can reach a verdict (for example
  uploaded JavaScript, which has no safe subset and whose capabilities are reachable through
  dynamic construction)
- **THEN** a default-off, fail-closed permission is the conforming remedy

#### Scenario: An existing permission already confers the capability
- **WHEN** the holders of an existing permission can already perform the action being gated
- **THEN** the change SHALL extend that permission rather than add one that would revoke the
  action from installs holding the existing grant
