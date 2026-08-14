# admin-action-verb-safety Specification

## Purpose
A state-changing admin endpoint must not be reachable over GET or HEAD, because Rails' CSRF
protection exempts those verbs entirely: a forged image tag or link must never trash content, flip
moderation, toggle plugins, send mail, switch a session to another user, or end a session. Actions
act only over verbs the CSRF check covers, and every first-party caller carries that verb with the
CSRF token.
## Requirements
### Requirement: State-changing admin endpoints act only over CSRF-protected verbs

The posts `trash` and `restore`, comments `toggle_status`, plugins `toggle` and `upgrade`, users
`impersonate`, and settings `test_email` endpoints SHALL be routed only over non-GET verbs (PATCH
or POST per their semantics). A GET or HEAD request to those paths SHALL NOT match the admin route
and SHALL perform no state change. First-party callers SHALL carry the verb and CSRF token —
`data-method` links where jquery_ujs is loaded, `button_to` forms or token-bearing ajax otherwise.

#### Scenario: Forged GETs perform nothing

- **WHEN** a signed-in admin's browser is made to GET any of the converted paths
- **THEN** no post is trashed or restored, no comment status flips, no plugin toggles or upgrades,
  no session switches, and no mail is sent

#### Scenario: The proper verb performs the action

- **WHEN** the admin UI submits the same action over its converted verb
- **THEN** the action executes exactly as before the conversion

#### Scenario: A new state-changing admin endpoint conforms

- **WHEN** a change proposes an admin endpoint that creates, mutates, or destroys state
- **THEN** it is routed only over verbs covered by the CSRF check, and its callers carry the verb;
  a GET route for it does not conform to this capability

### Requirement: Logout ends a session only over POST, with a GET confirmation

The logout path SHALL remain routable over GET for link compatibility, but a GET (or HEAD) SHALL
NOT end the session: it SHALL render a confirmation page whose submission POSTs the logout,
carrying the `full` parameter through. Only a POST SHALL invoke the session-ending logic (keyed on
`request.post?`, since HEAD is CSRF-exempt like GET). An impersonating session's logout SHALL keep
redirecting to the re-authentication flow, and a request that is no longer authenticated SHALL
still receive the logout cleanup (stale impersonation stash removal) on any verb.

#### Scenario: Forced-logout CSRF is dead

- **WHEN** a signed-in user's browser is made to GET the logout path
- **THEN** the session remains signed in and a confirmation page is shown

#### Scenario: POST ends the session

- **WHEN** the user submits the logout over POST (header button, confirmation page, or a theme's
  button_to)
- **THEN** the session ends as before

#### Scenario: Impersonation and de-authenticated cleanup are unchanged

- **WHEN** an impersonating session requests logout without `full=1`, or a request with a stale
  session and no valid authentication requests logout on any verb
- **THEN** the former is redirected to the re-authentication flow and the latter still has its
  session leftovers cleared

