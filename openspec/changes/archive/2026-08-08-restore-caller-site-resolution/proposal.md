# Proposal: restore-caller-site-resolution

## Why

On a multisite install, sending mail is broken. `HtmlMailer#sender` sets `@current_site` and then runs
`hooks_run('email_late', …)`, which calls `current_theme` → `SiteHelper#current_site`. At 2.9.2
`current_site` honored a caller-set `@current_site`; [#1177](https://github.com/owen2345/camaleon-cms/pull/1177)
replaced that branch with `return CurrentRequest.site if CurrentRequest.site.present?`. In a delivery
with no request-scoped site — a mailer, a background job, `deliver_later` — `CurrentRequest.site` is
blank, so resolution falls through to the branch that dereferences `request`, and a mailer has no
`request`: it raises `NameError`. On single-site installs the earlier `get_sites.size == 1` branch
returns `Site.first` and hides the bug; on multisite, password-reset, confirmation and admin-notification
mail all fail. This is finding **M21** in the 2.9.2→master regression audit, and it is a release blocker.

## What Changes

- `SiteHelper#current_site` honors a caller-set `@current_site` again — after the `$current_site` global
  and before the memoized `CurrentRequest.site` — writing it through to `CurrentRequest.site` and
  returning it. This restores 2.9.2 behavior and lets a background sender resolve hooks and theme against
  the site it set, without a request.
- Placed *before* the `CurrentRequest.site` check on purpose: an in-request `deliver_now` for another
  site must resolve against the caller's `@current_site`, not the request's memoized site.

## Capabilities

### New Capabilities

- `site-resolution-order`: the precedence `SiteHelper#current_site` follows and its no-request safety.

## Impact

- `app/helpers/camaleon_cms/site_helper.rb` (restore the `@current_site` branch)
- `spec/helpers/camaleon_cms/site_helper_spec.rb` (new — resolution order, no-request safety, and a
  multisite mailer reproducer)

`current_site` stays a plain overridable instance method — `camaleon-spree` reopens `SiteHelper` to
delegate it (`ecosystem-plugin-bindings`), so the fix must not move it to a prepend or `CurrentAttributes`.
