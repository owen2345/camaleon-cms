# Design

## D1. Allowlist the self-exemption, don't denylist the collection actions

The self-exemption is scoped to an allowlist of the six target-bearing member actions
(`SELF_TARGET_ACTIONS`) rather than by excluding `index`/`new`/`create`. An allowlist fails safe: a
member action must be named explicitly to gain the exemption, so any action added later — collection or
member — defaults to requiring `:manage, :users` until someone deliberately opts it into self-service. A
denylist of the current collection actions would leave a *future* collection action exposed by
omission, reintroducing exactly this bug.

The six actions are precisely those `validate_role` guards that resolve a single target user: the five
that load through the `set_user` filter (`show`/`edit`/`update`/`destroy`/`impersonate`) plus
`updated_ajax`, which resolves its own target. `profile`/`profile_edit` are already exempt from
`validate_role` entirely (`except: %i[profile profile_edit]`) and carry their own inline authorization.

## D2. Member self-service is untouched

The change alters behavior only for the actions outside the allowlist. For the member actions the
exemption logic is identical to before — the `user_id_param` resolution, the
`cama_current_user.id == user_id` comparison, and the `authorize!` fallback are unchanged — so a
non-manager can still view, edit, and change the password of their own record, and
`member_route_target_resolution_spec` and the `updated_ajax` specs pass without modification.
Preserving that path is why the fix narrows the exemption rather than removing it: the exemption exists
for a reason (self password change via `updated_ajax` for a user who does not manage other users), and
that reason applies only where there is a self to target.
