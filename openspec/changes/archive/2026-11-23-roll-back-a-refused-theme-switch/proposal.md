# Roll back a theme switch that fails

## Why

A theme switch in the admin panel calls `site_install_theme`. That helper does these steps, and no
transaction holds them:

- It runs the `on_inactive` hook of the old theme.
- It stores the key of the new theme in the `_theme` option of the site.
- It makes the theme records inactive, and it makes the record of the new theme.
- It runs the `on_active` hook of the new theme.

So an error in the `on_active` hook left the site half switched. An example is a role with the
`themes` permission and no `select_eval` permission. It switches to the `e_shop` theme of
`camaleon_website`, whose `on_active` handler adds a `select_eval` field. Camaleon refuses that field
with `CanCan::AccessDenied`. At that moment, the site has the key of `e_shop`, and the old theme
already ran its uninstall. The front page then failed with a template error, because `e_shop` was
half installed.

A route draw that fails during the switch had the same effect. The flash said that the routes stay
as they were, and the site had the new theme.

## What Changes

- `site_install_theme` runs the uninstall of the old theme and the install of the new theme in one
  savepoint (design D1). When a step raises, the error goes to the caller, and no row of the switch
  stays.
- After the rollback, `PluginRoutes` drops the data of the switch at once (design D2), and the
  request gets its old current theme back (design D3).
- **BREAKING**: a theme switch that fails the route trial now rolls back too. The site keeps its old
  theme, and the flash says that Camaleon did not save the change (design D4).
- A change that a hook makes outside the database does not roll back (design D5).
- A hook that raises `ActiveRecord::Rollback` fails the switch: `site_install_theme` then raises
  `ActiveRecord::ActiveRecordError` (design D6).
- The route trial runs in the savepoint, and the draw of the app routes runs after it.
  `PluginRoutes.trial_routes` returns a trial, and `PluginRoutes.reload` and
  `PluginRoutes.request_reload` take it as `trial:`. In a transaction of the caller, that draw uses
  the data of the trial. After the commit of the switch, it runs a trial again (design D7, D9).
- A savepoint that rolls back drops the route data that it used (design D8).
- The switch takes `CamaleonCms::RouteReloadLock` before its transaction. A request that starts
  during the switch waits until the switch is done (design D10). A reload of another thread waits
  for the switch for the wait time of the lock at most. While another switch holds the lock, a
  second call of the helper waits for 30 seconds at most, and then it raises an error.
- In a transaction of the caller that ran no statement, the helper forces a real savepoint with
  `CamaleonCms::CallerTransaction` (design D1).
- After a rollback, the request gets its old current theme back, for an exception of any class.
  The helper also resets the `themes` and the `plugins` of the site (design D3).
- A commit callback that raises after the commit leaves the theme switched. The helper then still
  draws the routes (design D7).
- After it takes the lock, the switch reads the theme of the site again. So a second switch starts
  from the theme that the first switch stored. The lock counts each fiber when the app isolates its
  state by fiber (design D10).
- A trial and the read for the memo of `Site.main_site` use no query cache. The reads for the site
  list and the plugin lists of `PluginRoutes` use none too (design D9).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `theme-install-hooks`: a theme switch is all or nothing.
- `multisite-route-draw-readiness`: the theme switch that fails the route trial keeps the old theme,
  and its flash says that Camaleon did not save the change. A reload takes a trial of
  `PluginRoutes.trial_routes`, and a savepoint that rolls back drops its route data. A reload waits
  for a thread that holds the lock for the wait time of the lock at most. `Site.main_site` reads the
  site for its memo with no query cache.

## Impact

- `app/helpers/camaleon_cms/site_helper.rb`: `site_install_theme`.
- `app/controllers/camaleon_cms/admin/appearances/themes_controller.rb` and
  `app/controllers/camaleon_cms/admin_controller.rb`: the message of a failed route trial.
- `lib/camaleon_cms/route_reload.rb`, `lib/camaleon_cms/route_trial.rb` and
  `lib/camaleon_cms/route_transaction_data.rb`: the trial of a reload and the route data of a
  savepoint.
- `lib/camaleon_cms/route_reload_lock.rb`: the wait of a reload for a thread that holds the lock.
- `lib/camaleon_cms/caller_transaction.rb`: the savepoint guard, which
  `app/models/concerns/camaleon_cms/custom_fields_read.rb` now shares.
- `lib/camaleon_cms.rb`: the `require` of that guard.
- `app/models/camaleon_cms/site.rb`: the read for the memo of `main_site`.
- `config/locales/camaleon_cms/admin/en.yml`: the message for a second switch that gets no lock.
- `docs/upgrading-to-2.9.5.md` and `docs/ai/ecosystem.md`.
- The surveyed themes install plugins and write custom fields, menus and posts in their `on_active`
  hooks. These are rows of the database, so they roll back with the switch.
