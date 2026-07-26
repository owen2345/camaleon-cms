## Context

`Admin::UsersController#profile` is excluded from the `validate_role` before_action because it is the only action whose target user is *optional* — with no `user_id` it renders the caller's own profile, and `validate_role` would fall through to `authorize!(:manage, :users)` on a blank id and lock non-admins out of their own profile. Change `2026-07-12-fix-profile-ido` therefore added an inline guard rather than folding `profile` back into `validate_role`. That reasoning still holds and is not revisited here.

What was not considered in that change is **ordering**. The inline guard derives its decision from the *loaded record* (`@user.id`), which forces the lookup to happen first:

```
                        current (master)
  user_id ──▶ the_user(id).object ──▶ authorize! ──▶ edit
                     │
                     └── nil.object ──▶ NoMethodError ──▶ 500   ← before any authz decision
```

Because the crash precedes the authorization decision, an unauthorized caller's response varies with the *existence* of the target — a `500` for unknown ids versus a `302` for known-but-forbidden ids. The authorization gate is correct; it is simply positioned downstream of an observable side effect.

Every other user-loading path in the controller already gets this right. `validate_role` (line 137) decides purely from `user_id_param` without touching the database, and it is registered at line 6 — *before* `set_user` at line 10 — so `show`/`edit`/`update`/`destroy` deny unauthorized callers before any lookup occurs and exhibit no oracle. `profile` is the outlier.

## Goals / Non-Goals

**Goals:**
- Make the `profile` response for an unauthorized caller independent of whether the requested user exists.
- Stop returning `500` for unknown, deleted, cross-site, and non-numeric `user_id` values.
- Reuse existing idioms and existing i18n keys; no new translation keys.

**Non-Goals:**
- Re-litigating why `profile` stays out of `validate_role` — settled in `2026-07-12-fix-profile-ido`.
- Changing `profile_edit`, `show`, `edit`, `update`, or `destroy`. None has this ordering problem.
- Hardening the *frontend* profile route (`GET /:label/:user_id-:user_name` → `FrontendController#profile`). That page is deliberately public and already returns `page_not_found` on a bad id.
- Changing the `the_user` decorator. Its swallow-and-return-`nil` contract is relied on by the shortcode call sites (`short_code_helper.rb:396`, `runtime_shortcode_theme_concern.rb:234`), which assign the result without dereferencing it. `users_controller.rb:20` is the only unguarded `.object` deref in the codebase, so the fix belongs at the call site.
- Cross-site visibility. `Site#users` (`site.rb:157`) returns `CamaleonCms::User.all` when the `users_share_sites` system setting is enabled, which is the shipped default (`config/system.json`). A user of another site is therefore an ordinary resolvable user, not a "not found" case, and is already governed by the `:manage :users` check. Nothing here changes that.

## Decisions

### 1. Authorize from the parameter, before the lookup

Move the guard above the assignment so the decision no longer depends on a loaded record:

```ruby
def profile
  add_breadcrumb I18n.t('camaleon_cms.admin.users.profile')
  user_id = params[:user_id]
  authorize! :manage, :users if user_id.present? && user_id.to_i != cama_current_user.id
  @user = user_id.present? ? current_site.the_user(user_id.to_i)&.object : cama_current_user.object
  return profile_not_found unless @user

  edit
end
```

A non-admin requesting any id other than their own is now denied before a query runs, so existence is unobservable. This also restores the invariant the rest of the controller follows: *authorization is a function of the request, not of the database.*

**Comparison semantics — integer, not string.** `validate_role` compares stringwise (`cama_current_user.id.to_s == user_id.to_s`), but `profile`'s lookup coerces with `to_i`. Comparing the same coerced integer that will be passed to `the_user` keeps the authorized value and the loaded value structurally identical — the guard authorizes exactly what it is about to fetch, eliminating any parser-differential gap between check and use. String comparison is also safe here (it only ever *over*-denies: `?user_id=05` or `+5` would be rejected for user 5), but it introduces a representation mismatch between the check and the query for no security gain, and would newly reject non-canonical self-ids that work today. Integer comparison preserves current behaviour for self-views and is the tighter invariant.

### 2. Reuse the `set_user` not-found idiom for the nil case

`set_user` (line 156) already defines how this controller reports an unresolvable user:

```ruby
flash[:error] = t('camaleon_cms.admin.users.message.error')   # "Not found user."
redirect_to cama_admin_path
```

`profile` should do the same rather than invent a 404 path. The key exists in every shipped locale file, so no translation work is required. With decision 1 in place, only an authorized caller (admin, or a user requesting their own id) can ever reach this branch, so the message leaks nothing.

### 3. Accept that admin and non-admin failure responses differ

After the change, an admin hitting an unknown id lands on `cama_admin_path` (`/admin`) with "Not found user.", while a denied non-admin lands on `cama_admin_dashboard_path` (`/admin/dashboard`) via the `rescue_from CanCan::AccessDenied` handler in `AdminController`. Different targets, but the distinction is only observable by callers who are *already* authorized to enumerate users, so it is not an oracle. Unifying the two would mean touching the shared `rescue_from`, which is out of scope.

## Behaviour Matrix

| caller | `user_id` | current | proposed |
| --- | --- | --- | --- |
| any | absent | own profile, `200` | unchanged |
| any | own id | own profile, `200` | unchanged |
| non-admin | other, exists | `302` → `/admin/dashboard` | unchanged |
| non-admin | nonexistent | **`500`** | `302` → `/admin/dashboard` |
| non-admin | non-numeric | **`500`** | `302` → `/admin/dashboard` |
| admin | other, exists | `200` | unchanged |
| admin | nonexistent | **`500`** | `302` → `/admin` + "Not found user." |
| admin | non-numeric | **`500`** | `302` → `/admin` + "Not found user." |

The three non-admin rows collapse to a single indistinguishable response — that is the security property being added. The two admin rows are the robustness fix.

## Risks / Trade-offs

- **[Low] Behaviour change for admins on bad ids.** A `500` becomes a redirect with a flash. Any downstream code asserting on the error status would need updating; nothing in this repo does.
- **[Low] Non-canonical self-ids.** Integer comparison (decision 1) preserves today's acceptance of `?user_id=05` for user 5. Chosen deliberately over `validate_role`'s stricter string comparison; see the rationale above.
- **[None] Admin flows.** Admins hold `:manage :users`, so the reordered `authorize!` is a no-op for them on valid ids.

## Verification

The oracle is a *differential* property, so the spec must assert that the non-admin failure modes produce the **same** status and the **same** redirect target — asserting each one individually against `302` would pass even if the responses differed in a distinguishing way.
