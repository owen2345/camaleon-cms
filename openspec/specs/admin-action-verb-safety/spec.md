# admin-action-verb-safety Specification

## Purpose
A state-changing admin endpoint must not be reachable over GET or HEAD, because Rails' CSRF
protection exempts those verbs entirely: a forged image tag or link must never trash content, flip
moderation, toggle plugins, send mail, switch a session to another user, or end a session. Actions
act only over verbs the CSRF check covers, and every first-party caller carries that verb with the
CSRF token.
## Requirements
### Requirement: State-changing admin endpoints act only over CSRF-protected verbs

A state-changing admin endpoint SHALL be routed only over non-GET verbs (PATCH, POST or DELETE per
its semantics, never `via: :all`). A GET or HEAD request to such a path SHALL NOT match the admin
route and SHALL perform no state change. The first scenario lists the converted endpoints.

#### Scenario: The converted endpoints are routed over non-GET verbs only

- **WHEN** the route set is read
- **THEN** these endpoints are routed only over PATCH, POST or DELETE, never `via: :all`
- **AND** they are the posts `trash` and `restore`, comments `toggle_status`, plugins `toggle` and
  `upgrade`, users `impersonate`, settings `test_email`
- **AND** they are the appearances themes `load_data`, appearances nav_menus `delete_menu_item`, the
  legacy appearances `widgets` and `widget_delete` endpoints, and media `crop`

#### Scenario: Forged GETs perform nothing

- **WHEN** a signed-in admin's browser is made to GET any of the converted paths
- **THEN** no post is trashed or restored, no comment status flips, no plugin toggles or upgrades,
  no session switches, no mail is sent, no nav-menu item is destroyed, and no cropped upload is
  written or avatar rewritten

#### Scenario: A new state-changing admin endpoint conforms

- **WHEN** a change proposes an admin endpoint that creates, mutates, or destroys state
- **THEN** it is routed only over verbs covered by the CSRF check, and its callers carry the verb
- **AND** a GET route for it does not conform to this capability
- **AND** an executable audit (`spec/routing/admin/state_changing_verb_audit_spec.rb`) walks the
  loaded route set
- **AND** the audit fails when a mutation-named admin route of Camaleon admits GET/HEAD outside a
  documented allowlist
- **AND** the allowlist holds only the deliberate logout / back_to_parent confirmation pair
- **AND** the audit enforces the invariant for all routes, not only per endpoint

### Requirement: First-party callers of a converted endpoint carry the verb and the CSRF token

First-party callers SHALL carry the verb and CSRF token. They use `data-method` links where
jquery_ujs is loaded, and `button_to` forms or token-bearing ajax otherwise.

#### Scenario: The proper verb performs the action

- **WHEN** the admin UI submits the same action over its converted verb
- **THEN** the action executes exactly as before the conversion

#### Scenario: JS-coupled callers send the verb with the token

- **WHEN** an admin caller issues the request from its own click handler rather than a link or
  form (the nav-menu item delete)
- **THEN** the handler sends the converted verb via ajax and jquery_ujs' prefilter attaches the
  CSRF token, so the action executes exactly as before the conversion
- **AND** an executable spec exercises the endpoint with forgery protection enabled — a token-less
  request is rejected and destroys nothing, while a request carrying the page's csrf-token meta (the
  token jquery_ujs replays) still performs the action — so CSRF enforcement is verified rather than
  assumed from the suite's disabled-forgery default

### Requirement: Logout ends a session only over POST, with a GET confirmation

The logout path SHALL remain routable over GET for link compatibility, but a GET (or HEAD) SHALL NOT
end the session. It SHALL render the confirmation page whose submission POSTs the logout. Only a
POST SHALL invoke the session-ending logic (keyed on `request.post?`, since HEAD is CSRF-exempt like
GET).

#### Scenario: Forced-logout CSRF is dead

- **WHEN** a signed-in user's browser is made to GET the logout path
- **THEN** the session remains signed in and a confirmation page is shown

#### Scenario: POST ends the session

- **WHEN** the user submits the logout over POST (header button, confirmation page, or a theme's
  button_to)
- **THEN** the session ends as before

### Requirement: The logout confirmation carries its parameters through to the POST

The confirmation SHALL carry the `full` (impersonation), `return_to` (vetted by the safe-redirect
check at logout), and `locale` parameters through to the POST. It SHALL treat each as a scalar. A
hash-shaped parameter SHALL be dropped, never an error. The Cancel link of the confirmation SHALL
honor the vetted `return_to`.

#### Scenario: A hash-shaped parameter is dropped from the logout confirmation

- **WHEN** a GET of the logout path carries `full`, `return_to` or `locale` as a hash-shaped
  parameter
- **THEN** the confirmation drops that parameter, and the request raises no error

#### Scenario: The logout confirmation carries the vetted parameters

- **WHEN** a GET of the logout path carries `full`, `return_to` and `locale` as scalars
- **THEN** the confirmation carries them through to the POST, and its Cancel link honors the vetted
  `return_to`

### Requirement: The logout confirmation answers in HTML and survives a stale CSRF token

The GET SHALL answer with the HTML confirmation regardless of requested format. A POST whose CSRF
token is stale SHALL re-render the confirmation rather than fail.

#### Scenario: A GET of any format gets the HTML confirmation

- **WHEN** a GET of the logout path asks for a format other than HTML
- **THEN** the answer is the HTML confirmation

#### Scenario: A POST with a stale CSRF token re-renders the confirmation

- **WHEN** a POST of the logout path carries a stale CSRF token
- **THEN** the confirmation renders again, and the request does not fail

### Requirement: Impersonation and de-authenticated logout keep their behavior

An impersonating session's logout SHALL keep redirecting to the re-authentication flow. A request
that is no longer authenticated SHALL still receive the logout cleanup (stale impersonation stash
removal) on any verb.

#### Scenario: Impersonation and de-authenticated cleanup are unchanged

- **WHEN** an impersonating session requests logout without `full=1`, or a request with a stale
  session and no valid authentication requests logout on any verb
- **THEN** the former is redirected to the re-authentication flow and the latter still has its
  session leftovers cleared
