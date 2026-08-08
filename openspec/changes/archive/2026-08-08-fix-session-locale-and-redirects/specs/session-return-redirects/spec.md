## Purpose

Define the `return_to` redirect policy for the admin session flows — which caller-supplied
destinations are followed and which fall back to the safe default — closing open redirects
without dropping legitimate same-host destinations.

## ADDED Requirements

### Requirement: return_to redirects are same-host with case-insensitive comparison

A caller-supplied `return_to` destination SHALL be followed only when it is relative (no host) or
absolute on the requesting host, and the host comparison SHALL be case-insensitive (host names
are case-insensitive per RFC 3986). A followed absolute destination SHALL be emitted with the
host in the request's canonical case, so the framework's own case-sensitive open-redirect
protection (`action_on_open_redirect`) stays active and never trips on a legitimate destination.
Cross-host and unparsable destinations SHALL be dropped in favor of the flow's safe default
path — never an error, never an off-host redirect. Cross-site destinations on multisite installs
are deliberately unsupported by this policy; supporting sibling sites would be a separate
security change.

The policy SHALL apply uniformly to every session flow that consumes `return_to`: visiting the
login page while already signed in, the post-login `return_to` cookie, and logout.

#### Scenario: Mixed-case same-host destination is followed

- **WHEN** a signed-in user opens `/admin/login?return_to=` naming the requesting host in a
  different letter case (e.g. `http://WWW.EXAMPLE.COM/admin/posts`)
- **THEN** the response redirects to that destination with the host in the request's canonical
  case

#### Scenario: Relative destination is followed

- **WHEN** a session flow consumes a `return_to` that is a relative path
- **THEN** the response redirects to that path

#### Scenario: Cross-host destination falls back

- **WHEN** a session flow consumes a `return_to` naming a different host
- **THEN** the response redirects to the flow's safe default path

#### Scenario: Unparsable destination falls back

- **WHEN** a session flow consumes a `return_to` that is not a parsable URI
- **THEN** the response redirects to the flow's safe default path

#### Scenario: Post-login cookie honors a mixed-case same-host destination

- **WHEN** a user logs in with a `return_to` cookie naming the requesting host in a different
  letter case
- **THEN** the response redirects to that destination with the host in the request's canonical
  case

#### Scenario: Logout honors a mixed-case same-host destination

- **WHEN** a signed-in user logs out with `?return_to=` naming the requesting host in a
  different letter case
- **THEN** the response redirects to that destination with the host in the request's canonical
  case after the session is closed
