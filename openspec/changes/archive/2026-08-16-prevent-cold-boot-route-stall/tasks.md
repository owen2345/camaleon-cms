# Tasks

## 1. Bounded route drawing (batch-perf)

- [x] 1.1 `PluginRoutes.get_sites` eager-loads `:metas`
- [x] 1.2 `all_enabled_plugins` resolves enabled slugs in one `parent_id IN (...)` query, short-circuited when there are no sites
- [x] 1.3 Specs: metas are eager-loaded; the plugin lookup is a single query, not one per site

## 2. Eager draw at boot (eager-draw)

- [x] 2.1 `PluginRoutes.draw_routes_eagerly` (skips under `eager_load`, guarded by `db_installed?`, rescued)
- [x] 2.2 Engine `after_initialize` calls it
- [x] 2.3 Specs: draws when lazy + DB installed; no-op when eager-loaded, when the DB is absent, or on failure

## 3. Uncacheable admin responses (no-store)

- [x] 3.1 `AdminController` sends `Cache-Control: no-store`, set ahead of authentication
- [x] 3.2 Spec: an admin response and the pre-auth redirect both carry `no-store`

## 4. Verification

- [x] 4.1 `bin/rubocop` — no offenses
- [x] 4.2 `bin/rspec` the new specs + `plugin_routes_spec` — green
- [x] 4.3 Full non-browser suite + brakeman + zeitwerk — green
- [x] 4.4 Changelog + archive at ship time
