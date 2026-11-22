## 1. Reproduce first

- [x] 1.1 Add `spec/lib/plugin_routes_trial_draw_spec.rb`. An enabled plugin gets a route file that
  raises an error, and the example calls `PluginRoutes.reload`. Verify: the example fails on the
  current code, because the app loses its routes
- [x] 1.2 Add two examples to `spec/requests/admin/settings/refused_site_save_spec.rb`. A site
  settings save carries a new slug while the routes cannot be drawn, as a form post and as an XHR.
  Each expects the answer of a refused save, with a message that names the error. Verify: they
  fail on the current code, because the slug is stored
- [x] 1.3 Add examples for `CamaleonCms::Site.main_site` to the spec of the site model. They cover a
  new slug of the main site, site ids that do not start at 1, and a first site whose create rolls
  back. Verify: the first and the last example fail on the current code
- [x] 1.4 Add `spec/lib/plugin_routes_transaction_data_spec.rb`. It covers a post type that a
  transaction creates, with the commit and with the rollback. It also covers a read of a list that
  is not loaded, and a value of `cache_variable`. Another thread reads `PluginRoutes.loaded_sites`.
  Verify: the examples fail on the current code
- [x] 1.5 Add examples for a post type to `spec/lib/plugin_routes_reload_once_spec.rb`. They cover a
  new slug in a transaction, a new slug outside a transaction, and a delete that rolls back.
  Verify: the first and the last example fail on the current code

## 2. The trial draw

- [x] 2.1 Add `PluginRoutes.route_set`, and make the three route files of Camaleon draw into it
  (design D1). Verify: `(cd spec/dummy && bin/rails routes)` prints the same routes as before
- [x] 2.2 Add the data object of a thread and the trial, with `PluginRoutes.check_routes` (design
  D2). Add `CamaleonCms::RouteDrawError` (design D10). Verify: the check examples of 1.1 pass
- [x] 2.3 Make `PluginRoutes.reload` run the trial first and draw from its data (design D3). Add the
  count of the reloads and the text of the route snippets. Verify: the examples of 1.1 pass, a
  reload reads the sites one time, and `spec/lib/plugin_routes_reload_once_spec.rb` passes
- [x] 2.4 Measure the time of `PluginRoutes.reload` before and after the change, back to back with
  `Benchmark`. Verify: the two numbers are in the first risk of `design.md`

## 3. The site

- [x] 3.1 Call `PluginRoutes.check_routes` in `Site`, in `after_update` for a new slug and in the
  first `before_destroy` (design D4). Verify: the example of 1.2 passes, and the examples of a delete pass
- [x] 3.2 Clear the memo of `CamaleonCms::Site.main_site` at a reload and after the commit of a
  site. Do not fill it in a trial or in an open transaction (design D5). Verify: the examples of 1.3
  pass
- [x] 3.3 Answer `CamaleonCms::RouteDrawError` in `AdminController`, with the two messages in
  `config/locales/camaleon_cms/admin/en.yml` (design D10). Verify: the examples of 1.2 pass, and an
  example of a languages save gets the message that the routes stay

## 4. The data of a transaction

- [x] 4.1 Add the test for an open transaction (design D6). Add the data object of a thread for a
  read and for a clear. Verify: the examples of 1.4 for the read and for `cache_variable` pass
- [x] 4.2 Add the settle step for the commit and for the rollback (design D6). Add the list of the
  data objects, and the reload that does not raise (design D9). Verify: the examples of 1.4 pass
- [x] 4.3 Call the settle step in `after_commit` and `after_rollback` of `Site` and `PostType`.
  Verify: the examples of 1.4 pass with no later read of `PluginRoutes` data
- [x] 4.4 Change the spec support that resets the cached data of `PluginRoutes`, when an example
  leaves a data object of a thread. Verify: the specs of `spec/lib` and `spec/requests/admin` pass
  in a random order

## 5. The reload after the commit

- [x] 5.1 Add `PluginRoutes.reload_after_commit` (design D7). Verify: its three scenarios pass as
  examples
- [x] 5.2 Call it in `PostType`, in `after_update` for a new slug and in `after_destroy` (design
  D8). Verify: the examples of 1.5 pass, and the draw counts of
  `spec/requests/admin/settings/sites_controller_spec.rb` stay

## 6. Documentation

- [x] 6.1 Write the comments of the new methods and of the changed callbacks. Verify: each comment
  says what the code does and why, in a few lines
- [x] 6.2 Change `docs/upgrading-to-2.9.5.md`. Add a section for the trial draw. Add a section for
  the post type draw after the commit, with its at-a-glance row. Change the sentences on the site
  list after a rollback. Change the `CHANGELOG.md` entry of the PR. Verify: the Markdown gate prints
  no line
- [x] 6.3 Read `docs/ai/ecosystem.md` for `PluginRoutes` and `main_site`, and record the new public
  methods there when the file lists the methods of `PluginRoutes`. Verify: the file names each new
  method, or the task notes that the file has no such list. Note: the file has no such list, so the
  new methods and the bindings of the survey are a new entry of its hardening hazards

## 7. Verification and shipping

- [x] 7.1 Run `bin/rubocop -A`, then `bin/rspec` on the new specs and the adjacent specs, then
  `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`. Run the whole suite
  when the adjacent specs are more than half of it. Verify: each check passes
- [x] 7.2 Run `openspec validate --all --strict`. Verify: the change is valid
- [x] 7.3 Fold the change into the description of PR 1364, and archive this change on the branch.
  Verify: `openspec validate --archived` passes
