# Tasks

## 1. The block of `PluginRoutes`

- [x] 1.1 Add `spec/lib/plugin_routes_reload_once_spec.rb` with an example for each scenario of "A
  draw that adds no route waits for the end of a block". Make sure that they fail before task 1.2.
- [x] 1.2 Add the module `CamaleonCms::RouteReload` with `reload`, `reload_once` and `request_reload`,
  and extend `PluginRoutes` with it. `reload` records the data of its draw (D1 to D7). The examples of
  task 1.1 pass, but for the plugin example that needs task 2.2.

## 2. The callers

- [x] 2.1 Add `spec/requests/admin/settings/sites_controller_spec.rb`. The create of a site draws
  the routes 3 times, and the delete one time. A create that is not valid draws nothing. Make sure
  that the two draw examples fail before task 2.2.
- [x] 2.2 Call `PluginRoutes.request_reload` in `PostType#refresh_routes`, `Site#refresh_routes`,
  `plugin_install` and `site_install_theme`. Open the blocks of D8 in `SitesController#create`,
  `SitesController#destroy` and `site_after_install`. The examples of task 2.1 pass.
- [x] 2.3 Keep the 10-second wait in `create_site` of `spec/features/admin/sites_spec.rb`, and
  correct its comment. The file passes.

## 3. Verification and shipping

- [x] 3.1 Add the section and the table row to `docs/upgrading-to-2.9.5.md`. They give the two new
  methods and what changes for a callback of `PluginRoutes.add_after_reload_routes`.
- [x] 3.2 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 3.3 Add the CHANGELOG entry, archive this change on the branch
