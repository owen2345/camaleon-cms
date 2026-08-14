# security-capability-gating Specification

## Purpose

A security-sensitive action is admin-only by default: a non-administrator role performs it only
through a dedicated permission that is off by default, seeded onto no role, and read as not-granted
by upgraded installations without a migration. The gate is an authorization decision on the acting
user — never a filesystem path, output filename, client flag or other proxy signal — and it fails
closed: no request context, or a failure while evaluating the permission, resolves to untrusted.
States as a checkable rule the convention the four existing permissions
(`post_content_unfiltered_html`, `contact_form_unfiltered_html`, `media_unfiltered_upload`,
`select_eval`) already follow, so a new dangerous capability must conform to it and cite it rather
than ship ungated, gate by a proxy, or fail open.
## Requirements
### Requirement: Security-sensitive actions are gated by a default-off role permission
Any action or method that presents a security threat SHALL be permitted for a non-administrator role
only when that role holds a dedicated permission for it. The permission SHALL be off by default: it
SHALL NOT be seeded onto any non-administrator role, so an existing installation reads it as
not-granted without a migration. Administrators SHALL satisfy the check through `can :manage, :all`
without the permission being present in role meta.

Conformant examples: `post_content_unfiltered_html`, `contact_form_unfiltered_html`,
`media_unfiltered_upload`, `select_eval`.

#### Scenario: An administrator performs the action
- **WHEN** a user with the `admin` role performs a gated security-sensitive action
- **THEN** it SHALL be allowed without the permission being present in any role meta

#### Scenario: A non-administrator without the permission
- **WHEN** a non-administrator role that does not hold the permission attempts the action
- **THEN** the restricted behavior SHALL apply — the action is refused, or its safe/sanitized path is
  taken

#### Scenario: A non-administrator granted the permission
- **WHEN** the permission is granted to a non-administrator role
- **THEN** that role SHALL be allowed to perform the action

#### Scenario: An upgraded installation
- **WHEN** a role's stored permission meta predates the new permission
- **THEN** the absent key SHALL read as not-granted, with no migration required

### Requirement: The permission check fails closed
The gate SHALL read the acting user and site from `CurrentRequest` and SHALL treat the caller as
untrusted when either is absent, so background jobs, rake tasks and the console get the restricted
behavior by default. A failure while evaluating the permission — for example malformed role meta —
SHALL resolve to untrusted rather than raising.

#### Scenario: No request context
- **WHEN** the action runs with no `CurrentRequest` user or site (a job, rake task, or console)
- **THEN** the caller SHALL be treated as untrusted and the restricted behavior SHALL apply

#### Scenario: Malformed permission data
- **WHEN** evaluating the permission raises
- **THEN** the gate SHALL resolve to untrusted rather than aborting the request

### Requirement: Authorization decides, not a proxy signal
The gate SHALL be an authorization check on the acting user. It SHALL NOT be decided by a filesystem
path, an output filename, a client-supplied parameter, a network location, or the mere fact that a
hook or handler ran. Where content or an action can be substituted after the check — such as a
`before_upload` handler replacing the scanned bytes — the substituted content SHALL be re-checked
against the permission rather than trusted.

#### Scenario: The same action reached by a different path
- **WHEN** the same bytes or action are presented under a different path or output filename
- **THEN** the authorization outcome SHALL be the same

#### Scenario: Content substituted after the check
- **WHEN** a hook replaces the checked content after the gate ran, for a caller without the permission
- **THEN** the substituted content SHALL be re-checked rather than accepted unscanned

### Requirement: New security-sensitive capabilities conform to this rule
When a change introduces an action or method that presents a security threat to non-administrator
roles, it SHALL gate it per this capability and SHALL cite this capability. It SHALL NOT ship the
action ungated, gate it by a non-authorization proxy, or let the check fail open.

#### Scenario: A proposal adds a dangerous action
- **WHEN** a proposal introduces a security-sensitive action available to non-administrators
- **THEN** it SHALL add a default-off, fail-closed permission gating it and reference this capability

#### Scenario: A proposal gates by a proxy signal
- **WHEN** a proposal would gate such an action by a path, filename, or client flag
- **THEN** it SHALL be revised to gate on the acting user's permission instead

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

