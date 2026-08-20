# admin-action-verb-safety

## MODIFIED Requirements

### Requirement: State-changing admin endpoints act only over CSRF-protected verbs

The posts `trash` and `restore`, comments `toggle_status`, plugins `toggle` and `upgrade`, users
`impersonate`, settings `test_email`, appearances themes `load_data`, appearances nav_menus
`delete_menu_item`, the legacy appearances `widgets` and `widget_delete` endpoints, and media
`crop` SHALL be routed only over non-GET verbs (PATCH, POST or DELETE per their semantics — never
`via: :all`). A GET or HEAD request to those paths SHALL NOT match the admin route and SHALL
perform no state change. First-party callers SHALL carry the verb and CSRF token — `data-method`
links where jquery_ujs is loaded, `button_to` forms or token-bearing ajax otherwise.

#### Scenario: Forged GETs perform nothing

- **WHEN** a signed-in admin's browser is made to GET any of the converted paths
- **THEN** no post is trashed or restored, no comment status flips, no plugin toggles or upgrades,
  no session switches, no mail is sent, no nav-menu item is destroyed, and no cropped upload is
  written or avatar rewritten

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

#### Scenario: A new state-changing admin endpoint conforms

- **WHEN** a change proposes an admin endpoint that creates, mutates, or destroys state
- **THEN** it is routed only over verbs covered by the CSRF check, and its callers carry the verb;
  a GET route for it does not conform to this capability
- **AND** an executable audit (`spec/routing/admin/state_changing_verb_audit_spec.rb`) walks the
  loaded route set and fails when a mutation-named core admin route admits GET/HEAD outside a
  documented allowlist — after this change only the deliberate logout / back_to_parent
  confirmation pair — so the invariant is enforced rather than only asserted per endpoint
