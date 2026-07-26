## Context

`CamaleonCms::Admin::UsersController` guards every action except `profile`/`profile_edit` with a `validate_role` filter. Historically that filter and the actions it guards read the target user from *different* request parameters, which produced the account takeover fixed in PR [#1185](https://github.com/owen2345/camaleon-cms/pull/1185) (commit `97e20509`): `validate_role` resolved `params[:id] || params[:user_id]` while `updated_ajax` loaded `params[:user_id]` directly.

The controller exposes two route families, and which parameter carries the path segment differs between them:

| Route | Path segment lands in | Injectable key |
|---|---|---|
| `PATCH /admin/users/:user_id/updated_ajax` (nested) | `params[:user_id]` | `params[:id]` |
| `/admin/users/:id` — `show`/`edit`/`update`/`destroy`/`impersonate` (member) | `params[:id]` | `params[:user_id]` |

Rails merges path parameters last (`ActionDispatch::Http::Parameters#parameters`), so the path segment always beats a query-string or body value of the same name. The injectable key in each row is the one the route does not populate.

The fix unified both sides onto `user_id_param` (`params[:user_id] || params[:id]`). The controller is correct on master. What is missing is any durable record of *why* it is correct, and any test covering the member-route half.

Separately, the same endpoint is inconsistent about how it reports failures. `updated_ajax` rescues `ActionController::ParameterMissing` into a short plain-text body, but a lookup that finds no record falls through to the framework's default HTML error page — rendered inside an admin modal that displays the response body directly. That inconsistency is folded into this change because it lives in the one method whose resolution behavior is being specified here.

Constraints:

- `spec/requests/admin/users_controller/update_spec.rb:15` stubs `validate_role` to return `true`. That spec exists to cover avatar-meta persistence, not authorization.
- AGENTS.md requires integration/request specs over controller specs for security coverage, and directs against refactoring code that is not broken.

## Goals / Non-Goals

**Goals:**

- State the canonical-resolution invariant as a testable requirement, so a future edit that reintroduces divergent parameter reads fails a spec rather than shipping.
- State the security outcome (a caller without `:manage`/`:users` can only ever target themselves) independently of the helper that currently delivers it.
- Close the member-route coverage gap with request specs.
- Record the member-route precedence consequence explicitly rather than leaving it to be rediscovered by the next report.

- Make `updated_ajax` report an unresolvable target in the same plain-text format it already uses for parameter errors.

**Non-Goals:**

- Changing the controller to satisfy the resolution invariant. It already does; only the `updated_ajax` rescue is new code.
- Changing the helper's precedence to make the path segment authoritative on member routes (see Open Questions).
- Changing the `404` status of an unresolvable target, or making found/not-found responses indistinguishable. Neither is warranted here (see Decisions).
- Re-specifying `GET /admin/profile`, which is covered by `profile-authorization`.
- Un-stubbing `update_spec.rb`.

## Decisions

**A new capability rather than an extension of `profile-authorization`.** `profile-authorization` covers a single endpoint that is explicitly exempt from `validate_role` and authorizes inline. This capability covers the complementary set — everything the filter *does* guard — and its central claim is about agreement between two code paths, not about one endpoint's rules. Folding them together would blur which endpoints the exemption applies to. The new spec names the boundary so the pair reads as a partition.

**Two requirements for one property: mechanism and outcome.** "Authorization and mutation resolve through one helper" is the mechanism; "a non-admin can only ever target themselves" is the outcome. Specifying only the mechanism would let a refactor that removes `user_id_param` technically satisfy the spec while reopening the hole. Specifying only the outcome would lose the design rule that makes the outcome cheap to verify by reading the controller. Both are stated.

**Request specs, not controller specs.** Per AGENTS.md, and because the whole class of bug is about how Rails merges path, query, and body parameters — precisely the layer a controller spec bypasses. The existing `updated_ajax_vulnerability_spec.rb` is the model to follow; new member-route coverage sits beside it.

**New dedicated specs rather than reworking `update_spec.rb`.** That file's `validate_role` stub is appropriate for what it tests. Removing the stub would force it to construct authorization fixtures irrelevant to avatar-meta persistence. Authorization gets its own files; the stub stays and is noted in the proposal so a reader does not mistake that file for coverage.

**Rescue `RecordNotFound` for body format, not for status.** An earlier draft of this document claimed a bad id on `updated_ajax` produced an unhandled `500` and framed the fix as the same robustness class as PR [#1213](https://github.com/owen2345/camaleon-cms/pull/1213). Both claims were wrong. `activerecord/railtie.rb` maps `ActiveRecord::RecordNotFound` to `:not_found`, so the status is already `404`; and `#1213` was a genuine `NoMethodError` because `current_site.the_user` *returns nil* for an unknown id, whereas `find` *raises*. Different mechanism, different severity.

The real defect is narrower: the action rescues `ActionController::ParameterMissing` into a plain-text body but lets a missing record fall through to the framework's HTML error page, and the caller is a modal form that renders the body. So the rescue is added for response-format consistency, keeping the `404` and reusing `camaleon_cms.admin.users.message.error` — the key `set_user` already uses, so no new translations.

Two things this decision deliberately does *not* copy from `#1213`. It does not redirect the way `set_user` does, because a redirect to the admin dashboard is wrong for an XHR endpoint whose other error paths return status-plus-body. And it does not make found and not-found responses uniform, because there is no oracle to close: `validate_role` runs first and admits only the target themselves or a holder of `:manage` on `:users`, so a caller who can reach the lookup with a foreign id can already list every user.

**Specify the member-route retarget rather than omit it.** Stating that `PATCH /admin/users/A?user_id=B` edits B is uncomfortable, but an unstated surprise in this controller is exactly what produced two reports. The spec states it *and* states why it is not an escalation, so a future reader can tell the difference between a quirk and a hole without re-deriving it.

## Risks / Trade-offs

- **Codified quirk reads as endorsement** → The requirement text says the behavior is observable and specified, not desirable, and Open Questions carries the proposal to change it. Should precedence later be inverted, this requirement is the one to modify.
- **Member-route retarget becomes exploitable if a future action authorizes differently** → Mitigated by the outcome requirement, which forbids a non-admin from acting on any user but themselves regardless of mechanism, and by scenarios that exercise `update`, `destroy`, and `impersonate` rather than one action.
- **Scenarios pin implementation detail (parameter names) into specs** → Accepted deliberately. The parameter names *are* the contract here; the vulnerability class is defined by them. A spec written at a higher level of abstraction could not have caught the original bug.
- **Spec-only change may be read as busywork at review time** → The proposal leads with the two-reports history and the concrete untested surface.
- **The new rescue masks a genuine lookup failure** → It catches `ActiveRecord::RecordNotFound` only, not `StandardError`, so a connection error or a bug inside the lookup still surfaces as a `500` rather than being reported as a missing user. This is deliberately narrower than `set_user`'s blanket rescue (see Open Questions).
- **A `404` with a body could be mistaken for closing an oracle** → The spec states in the requirement text that response uniformity is not a goal here and why, so a future reader does not infer a security property this change does not provide.

## Open Questions

- **Should the helper's precedence be inverted to `params[:id] || params[:user_id]`, or made route-aware, so the path segment is always authoritative?** Nothing in `app/views/camaleon_cms/admin/users/` or the bundled admin JavaScript passes `user_id` explicitly — on member routes it only ever arrives by injection, so inverting it appears inert within this repo. But AGENTS.md notes most plugins and themes ship as separate gems whose link and form helpers cannot be enumerated from here, so "inert" cannot be verified for downstream consumers. This needs its own change with its own compatibility assessment; it is not folded in here.
- **Should `set_user`'s blanket `rescue StandardError` be narrowed to `ActiveRecord::RecordNotFound`?** It currently swallows every exception from the lookup into a "not found user" redirect, which would mask an unrelated failure — a connection error, a decorator bug — as a missing record. Narrowing it is a one-line change, but it alters behavior for the five member actions rather than the one endpoint this change touches, and any downstream code relying on the broad rescue would fail differently. Left alone here; worth its own change with its own regression coverage.
