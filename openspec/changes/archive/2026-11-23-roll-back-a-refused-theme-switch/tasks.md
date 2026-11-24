# Tasks

## 1. Reproduce the half-installed theme

- [x] 1.1 Add `spec/requests/theme_switch_rollback_spec.rb`. A role with the `themes` permission
  and no `select_eval` permission switches to the theme `new`. Its `on_active` handler installs a
  plugin, adds a field group with a text field, and then adds a `select_eval` field. Verify: the
  theme key, the theme records and the field group fail on the current code. The front page shows
  the theme `new`
- [x] 1.2 Add an example in which a `front_before_load` handler switches the theme and rescues the
  error. Verify: the page fails on the current code with the template error of a theme that is half
  installed

- [x] 1.3 Add examples for the later cases to `spec/requests/theme_switch_rollback_spec.rb`. The
  cases are a transaction of the caller, `ActiveRecord::Rollback`, a stopped transaction, a commit
  callback that raises, and an exception that is no `StandardError`
- [x] 1.4 Add examples for the draw after the savepoint to
  `spec/requests/admin/appearances/themes_controller_spec.rb`, for `PluginRoutes.trial_routes` to
  `spec/lib/plugin_routes_trial_draw_spec.rb`, and for a savepoint to
  `spec/lib/plugin_routes_transaction_data_spec.rb`. Add
  `spec/lib/plugin_routes_trial_query_cache_spec.rb` for a trial in a request, and
  `spec/models/site_main_site_query_cache_spec.rb` for the main site
- [x] 1.5 Add `spec/requests/theme_switch_connection_lease_spec.rb`,
  `spec/requests/theme_switch_site_records_spec.rb`,
  `spec/requests/theme_switch_route_lock_spec.rb` and
  `spec/requests/theme_switch_after_another_switch_spec.rb`

## 2. Roll the switch back

- [x] 2.1 Run the steps of `site_install_theme` in one savepoint (design D1). Restore the current
  theme of the request, and settle the data of `PluginRoutes`, when a step raises (design D2, D3).
  Verify: the specs of 1.1 and 1.2 pass
- [x] 2.2 Remove the `rolled_back: false` argument of the themes controller and the keyword of
  `route_draw_error_message` (design D4). Change the two route draw examples of
  `spec/requests/admin/appearances/themes_controller_spec.rb`. They now expect the old theme, and
  the message for a change that was not saved. Verify: the adjacent specs pass
- [x] 2.3 Add a section and an at-a-glance row to `docs/upgrading-to-2.9.5.md`. Change its text of
  the theme switch that fails the trial. Add the survey to `docs/ai/ecosystem.md`. Verify: the
  anchor of the row resolves to the heading of the section, and the Markdown gate prints no line

- [x] 2.4 Raise `ActiveRecord::ActiveRecordError` when `ActiveRecord::Rollback` rolls the switch
  back, from a hook or from a `before_commit` callback (design D6). Read the site before and after
  the route trial, so a transaction that PostgreSQL stopped fails the switch
- [x] 2.5 Add `PluginRoutes.trial_routes` and the `trial:` keyword of `reload` and `request_reload`.
  Run the trial in the savepoint, and draw the app routes after it from that trial (design D7, D9).
  Give the error of that draw with `in_transaction?` false (design D4).
  A reload runs a trial again when the transaction of its trial rolled back.
  A reload with a trial draws nothing when its thread already drew the routes from stored rows that
  it read after that trial.
  Load the route files of a trial with no query cache
- [x] 2.6 Drop the route data of a savepoint that rolls back (design D8). Give the thread empty
  data after the rollback of a savepoint that had data of its own. Count a transaction that no
  other transaction can join as an open transaction of `PluginRoutes`
- [x] 2.7 End a failed switch for an exception of any class. Give the request its old theme back,
  and reset the `themes` and the `plugins` of the site (design D3). Settle the data of
  `PluginRoutes` (design D2). After the error of a commit callback, draw the routes (design D7)
- [x] 2.8 Read the transaction of the switch with no connection lease. Force a real savepoint in a
  transaction of the caller with `CamaleonCms::CallerTransaction` (design D1). While the pool has a
  transaction isolation level, raise the error before the savepoint, so the caller keeps its
  connection
- [x] 2.9 Take `CamaleonCms::RouteReloadLock` before the transaction of the switch (design D10).
  Give a reload that waits for the thread that holds the lock the wait time of the lock.
  Make a switch wait for that thread for `HOLDER_WAIT_TIMEOUT` seconds, and then raise `WaitTimeout`.
  Give the wait for the requests and the wait for that thread a time each.
  After the lock is taken, read the theme of the site again, with no memo and no query cache.
  Verify: the examples of 1.3 to 1.5 pass
- [x] 2.10 Record the later changes and the intended limits in the requirements, the design,
  `docs/upgrading-to-2.9.5.md` and `docs/ai/ecosystem.md`. Verify: the Markdown gate prints no line
- [x] 2.11 Read the main site for the memo of `Site.main_site` with no query cache (design D9)
- [x] 2.12 Make the lock count each fiber when the isolation level of the app is `:fiber` (design
  D10)
- [x] 2.13 After the lock is taken, load again the metas that the site holds in memory (design D10)
- [x] 2.14 Make a reload run a trial again when the transaction of its trial committed (design D9)
- [x] 2.15 Read the site list and the plugin lists of `PluginRoutes` with no query cache (design D9)
- [x] 2.16 Keep the state of the outermost transaction in a trial (design D9). A reload in a later
  transaction then runs a trial again

## 3. Archive

- [x] 3.1 Archive the change with `/opsx:archive`, and commit the archive in the PR
