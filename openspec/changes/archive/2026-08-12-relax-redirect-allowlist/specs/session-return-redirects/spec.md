## ADDED Requirements

### Requirement: Trusted off-site redirect destinations

This requirement defines the only exceptions to the same-host redirect policy above. An off-site
(non-same-host) destination SHALL be followed only when it is `http`/`https` AND either its host is on a
configured allowlist, or the initiating server-side caller explicitly vouches for it. A non-`http`/`https`
scheme (e.g. `javascript:`, `data:`) SHALL be rejected regardless of allowlist or opt-in.

The allowlist SHALL be empty by default — so the same-host policy holds until a host is explicitly
trusted — and SHALL be sourced from the `redirect_allowed_hosts` site option (comma-separated, host
compared case-insensitively) and the `safe_redirect_hosts` hook (handlers append trusted hosts to
`r[:hosts]`).

The explicit opt-in SHALL be available only on server-set redirect arguments — `login_user`'s
`redirect_url` (via `allow_external`, set from the `after_login` hook's `r[:allow_external_redirect]`) and
the registration `user_registered` redirect — and SHALL NOT be reachable from a caller-controlled
`return_to` (URL parameter or cookie).

A followed off-site destination SHALL be emitted so the framework's open-redirect backstop permits it
(Rails 7+ `allow_other_host`); on the Rails 6.1 floor, which has no backstop, no such marker is needed. A
same-host destination SHALL NOT carry that marker, keeping the backstop active as a second layer.

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

#### Scenario: A caller-controlled return_to cannot opt in

- **WHEN** a `return_to` URL parameter or cookie names an off-site host that is not allowlisted
- **THEN** the response redirects to the flow's safe default path, regardless of any hook opt-in

#### Scenario: A trusted destination cannot carry a non-http scheme

- **WHEN** an allowlisted or opted-in destination uses a non-`http`/`https` scheme (e.g.
  `javascript://allowlisted-host/...`)
- **THEN** the response redirects to the flow's safe default path
