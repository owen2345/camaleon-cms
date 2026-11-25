# session-return-redirects Specification

## Purpose
Define the `return_to` redirect policy for the admin session flows — which caller-supplied
destinations are followed and which fall back to the safe default — closing open redirects
without dropping legitimate same-host destinations.
## Requirements
### Requirement: return_to redirects are same-host with case-insensitive comparison

A caller-supplied redirect destination SHALL be followed only when it is a genuine same-origin
reference. One case is an absolute URL on the requesting host over an `http`/`https` (or
scheme-relative) scheme. The other case is a same-origin path, which is one leading `/` followed by
a normal path character. The host comparison SHALL be case-insensitive per RFC 3986.

#### Scenario: Mixed-case same-host destination is followed

- **WHEN** a signed-in user opens `/admin/login?return_to=` naming the requesting host in a
  different letter case (e.g. `http://WWW.EXAMPLE.COM/admin/posts`)
- **THEN** the response redirects to that destination with the host in the request's canonical
  case

#### Scenario: Relative destination is followed

- **WHEN** a session flow consumes a `return_to` that is a relative path
- **THEN** the response redirects to that path

### Requirement: A same-host destination is emitted with the host in the request's canonical case

A same-host absolute URL SHALL be emitted with the host in the request's canonical case, so the
framework's own open-redirect protection stays active.

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

### Requirement: A same-host destination with a non-http scheme is dropped

A host-matching absolute URL that has any other scheme SHALL be dropped. A `javascript:` or `data:`
destination that embeds the request host (`javascript://requesthost/...`) parses as same-host. It is
not a real navigation, and it would execute if rendered into an `href` or JS sink.

#### Scenario: Same-host destination with a non-http scheme falls back

- **WHEN** a session flow consumes a destination whose parsed host matches the request host but whose
  scheme is not `http`/`https` (e.g. `javascript://www.example.com/...`, `data://www.example.com/x`)
- **THEN** the response redirects to the flow's safe default path

### Requirement: A destination with a blank host that resolves off-site is dropped

A destination whose parsed host is blank but which a browser would still resolve off-site SHALL be
dropped. These are a scheme (`https:evil.com`, `javascript:...`), a protocol-relative or backslash
form (`///evil.com`, `/\evil.com`), and their `%2f` and `%5c` encodings.

#### Scenario: Host-blank off-site destination falls back

- **WHEN** a session flow consumes a `return_to` whose parsed host is blank but which resolves off-site
  or trips the redirect backstop (`///evil.com`, `https:evil.com`, `javascript:...`, `/%5cevil.com`)
- **THEN** the response redirects to the flow's safe default path

### Requirement: Cross-host and unparsable destinations fall back to the safe default path

Cross-host and unparsable destinations SHALL be dropped in favor of the safe default path of the
flow, never an error and never an off-host redirect. The policy SHALL NOT support cross-site
destinations on multisite installs.

#### Scenario: Cross-host destination falls back

- **WHEN** a session flow consumes a `return_to` naming a different host
- **THEN** the response redirects to the flow's safe default path

#### Scenario: Unparsable destination falls back

- **WHEN** a session flow consumes a `return_to` that is not a parsable URI
- **THEN** the response redirects to the flow's safe default path

#### Scenario: A destination on a sibling site of a multisite install falls back

- **WHEN** a session flow consumes a destination on another site of a multisite install
- **THEN** the response redirects to the flow's safe default path
- **AND** support for sibling sites is a separate security change

### Requirement: The same-host policy applies to every session flow that consumes a destination

The policy SHALL apply uniformly to every session flow that consumes a caller-supplied destination.
These flows are: a visit to the login page while the user is signed in, the post-login `return_to`
cookie, and logout. They also include the explicit `redirect_url` argument of `login_user` (set by
`after_login` hooks and downstream plugins). The last flow is the post-registration redirect (set by
the `user_registered` hook and downstream plugins).

#### Scenario: Explicit login redirect argument is host-checked

- **WHEN** `login_user` is given an off-site explicit `redirect_url` (e.g. set by an `after_login` hook)
- **THEN** the response redirects to the dashboard rather than the off-site destination

#### Scenario: Explicit registration redirect is host-checked

- **WHEN** the `user_registered` hook sets an off-site `redirect_url` for a successful registration
- **THEN** the response redirects to the login path rather than the off-site destination

### Requirement: Trusted off-site redirect destinations

This requirement defines the only exceptions to the same-host redirect policy above. An off-site
(non-same-host) destination SHALL be followed only when it is `http`/`https`. Its host must also be
on a configured allowlist, or the initiating server-side caller must explicitly vouch for it.

#### Scenario: Allowlisted host is followed

- **WHEN** a session flow consumes a destination whose host is listed in `redirect_allowed_hosts` (or
  added by a `safe_redirect_hosts` handler) over `http`/`https`
- **THEN** the response redirects to that destination

#### Scenario: Non-allowlisted off-site host falls back

- **WHEN** a session flow consumes an off-site destination whose host is not allowlisted and for which no
  caller opt-in applies
- **THEN** the response redirects to the flow's safe default path

#### Scenario: Hook-vouched off-site destination is followed

- **WHEN** an `after_login` or `user_registered` hook sets an off-site `redirect_url` and opts in via
  `r[:allow_external_redirect]`
- **THEN** the response redirects to that off-site destination

### Requirement: A trusted off-site destination cannot use a non-http scheme

A non-`http`/`https` scheme (e.g. `javascript:`, `data:`) SHALL be rejected regardless of allowlist
or opt-in.

#### Scenario: A trusted destination cannot carry a non-http scheme

- **WHEN** an allowlisted or opted-in destination uses a non-`http`/`https` scheme (e.g.
  `javascript://allowlisted-host/...`)
- **THEN** the response redirects to the flow's safe default path

### Requirement: The redirect allowlist is empty by default

The allowlist SHALL be empty by default, so the same-host policy holds until a host is explicitly
trusted. It SHALL come from the `redirect_allowed_hosts` site option (comma-separated, host compared
case-insensitively) and the `safe_redirect_hosts` hook. Handlers of that hook append trusted hosts
to `r[:hosts]`.

#### Scenario: An empty allowlist trusts no off-site host

- **WHEN** no `redirect_allowed_hosts` option and no `safe_redirect_hosts` handler list a host, and
  a session flow consumes an off-site destination
- **THEN** the response redirects to the flow's safe default path

### Requirement: The explicit redirect opt-in is available only on server-set redirect arguments

The explicit opt-in SHALL be available only on server-set redirect arguments. These are the
`redirect_url` of `login_user` (through `allow_external`, set from `r[:allow_external_redirect]` of
the `after_login` hook) and the registration `user_registered` redirect. It SHALL NOT be reachable
from a caller-controlled `return_to` (URL parameter or cookie).

#### Scenario: A caller-controlled return_to cannot opt in

- **WHEN** a `return_to` URL parameter or cookie names an off-site host that is not allowlisted
- **THEN** the response redirects to the flow's safe default path, regardless of any hook opt-in

### Requirement: A followed off-site destination carries the open-redirect marker

A followed off-site destination SHALL be emitted so the framework's open-redirect backstop permits
it (Rails 7+ `allow_other_host`). On the Rails 6.1 floor, which has no backstop, no such marker is
needed. A same-host destination SHALL NOT carry that marker, so the backstop stays active as a
second layer.

#### Scenario: A followed off-site destination is emitted with allow_other_host

- **WHEN** a session flow follows an allowlisted off-site destination on Rails 7 or later
- **THEN** the redirect carries `allow_other_host`

#### Scenario: A same-host destination carries no allow_other_host marker

- **WHEN** a session flow follows a same-host destination
- **THEN** the redirect carries no `allow_other_host` marker, so the backstop stays active
