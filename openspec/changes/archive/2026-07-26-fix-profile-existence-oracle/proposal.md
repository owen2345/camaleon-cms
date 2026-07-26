## Why

The profile IDOR fixed in [#1197](https://github.com/owen2345/camaleon-cms/pull/1197) (change `2026-07-12-fix-profile-ido`) closed the profile *disclosure*, but left the enumeration half of the report partially open, because the authorization check runs **after** the user lookup and the lookup is not nil-safe:

```ruby
@user = user_id.present? ? current_site.the_user(user_id.to_i).object : cama_current_user.object
authorize! :manage, :users if user_id.present? && @user.id != cama_current_user.id
```

`current_site.the_user(id)` returns `nil` for an unknown id, so `.object` raises `NoMethodError` before `authorize!` is ever reached. Verified against `master` with a low-privilege (`client`) session:

| request | observed |
| --- | --- |
| `?user_id=<existing other user>` | `302` → `/admin/dashboard` (denied, correct) |
| `?user_id=999999` | `NoMethodError: undefined method 'object' for nil` → `500` |
| `?user_id=abc` | `NoMethodError: undefined method 'object' for nil` → `500` |

Two defects follow from the one root cause:

1. **User-existence oracle (security, low severity).** An authenticated low-privilege user can still distinguish "user id N exists on this site" (`302`) from "it does not" (`500`) by walking sequential ids. No PII is disclosed, so this is far weaker than the original finding, but it is the enumeration primitive from that report surviving in degraded form.
2. **Unhandled exception (robustness).** *Any* caller — including a legitimate admin — gets a `500` for a nonexistent, deleted, or non-numeric `user_id`. The sibling `set_user` callback already handles exactly this case gracefully; `profile` is the only user-loading path in the controller that does not.

## What Changes

- Decide authorization in `Admin::UsersController#profile` from the request parameter **before** loading the target user, so an unauthorized caller's response is identical whether or not the requested id exists.
- Nil-guard the profile lookup and reuse the existing `set_user` not-found idiom (flash `camaleon_cms.admin.users.message.error` + redirect to `cama_admin_path`) instead of dereferencing `nil`.
- Extend the request spec and the `profile-authorization` capability with the nonexistent-id and non-numeric-id cases.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `profile-authorization`: authorization is now specified as a function of the request parameter evaluated before any user lookup, and the capability gains a requirement covering unknown/unresolvable target users.

## Impact

- `app/controllers/camaleon_cms/admin/users_controller.rb` — `profile` action only (~4 lines).
- `spec/requests/admin/users_controller/profile_spec.rb` — new scenarios.
- No new i18n keys: `camaleon_cms.admin.users.message.error` ("Not found user.") already exists in all shipped locale files, so no churn across the 20+ translations.
- No route, model, ability, or decorator changes. `the_admin_profile_url` keeps generating canonical ids, so admin views are unaffected.
