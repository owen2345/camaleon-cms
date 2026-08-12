# session-return-redirects Specification

## Purpose
Define the `return_to` redirect policy for the admin session flows — which caller-supplied
destinations are followed and which fall back to the safe default — closing open redirects
without dropping legitimate same-host destinations.
## Requirements
### Requirement: return_to redirects are same-host with case-insensitive comparison

A caller-supplied redirect destination SHALL be followed only when it is a genuine same-origin reference:
either an absolute URL on the requesting host over an `http`/`https` (or scheme-relative) scheme (host
comparison case-insensitive per RFC 3986, emitted with the host in the request's canonical case so the
framework's own open-redirect protection stays active), or a same-origin path — one leading `/` followed
by a normal path character. A host-matching absolute URL carrying any other scheme SHALL be dropped: a
`javascript:`/`data:` destination that embeds the request host (`javascript://requesthost/...`) parses as
same-host yet is not a real navigation and would execute if rendered into an `href`/JS sink. A destination
whose parsed host is blank but which a browser would still resolve off-site SHALL likewise be dropped: a
scheme (`https:evil.com`, `javascript:...`), a protocol-relative or backslash form (`///evil.com`,
`/\evil.com`), and their `%2f` / `%5c` encodings. Cross-host and unparsable destinations SHALL likewise be
dropped in favor of the flow's safe default path — never an error, never an off-host redirect. Cross-site
destinations on multisite installs are deliberately unsupported by this policy; supporting sibling sites
would be a separate security change.

The policy SHALL apply uniformly to every session flow that consumes a caller-supplied destination:
visiting the login page while already signed in, the post-login `return_to` cookie, logout,
`login_user`'s explicit `redirect_url` argument (set by `after_login` hooks and downstream plugins), and
the post-registration redirect (set by the `user_registered` hook and downstream plugins).

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

#### Scenario: Host-blank off-site destination falls back

- **WHEN** a session flow consumes a `return_to` whose parsed host is blank but which resolves off-site
  or trips the redirect backstop (`///evil.com`, `https:evil.com`, `javascript:...`, `/%5cevil.com`)
- **THEN** the response redirects to the flow's safe default path

#### Scenario: Same-host destination with a non-http scheme falls back

- **WHEN** a session flow consumes a destination whose parsed host matches the request host but whose
  scheme is not `http`/`https` (e.g. `javascript://www.example.com/...`, `data://www.example.com/x`)
- **THEN** the response redirects to the flow's safe default path

#### Scenario: Explicit login redirect argument is host-checked

- **WHEN** `login_user` is given an off-site explicit `redirect_url` (e.g. set by an `after_login` hook)
- **THEN** the response redirects to the dashboard rather than the off-site destination

#### Scenario: Explicit registration redirect is host-checked

- **WHEN** the `user_registered` hook sets an off-site `redirect_url` for a successful registration
- **THEN** the response redirects to the login path rather than the off-site destination

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

