# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/admin/settings/refused_site_save_spec.rb`. With two sites, it refuses a
  site settings save that carries a new slug. The refused parts are `values` that the permit cannot
  read, an invalid group number and a metas container that is not a set of fields. It also refuses
  a save by XHR and a save that keeps the slug. Verify: each of these examples fails on the current
  controller

- [x] 1.2 Add examples for a site that changes in a transaction to
  `spec/lib/plugin_routes_reload_once_spec.rb`, and read the list of `PluginRoutes.get_sites` in
  the spec of 1.1. Verify: the examples of a rollback and of a second save fail on the current model

## 2. The site settings save

- [x] 2.1 Add `save_site_with_fields` to `SettingsController` and call it from `site_saved` (design
  D1 to D3). Verify: the spec of 1.1 passes, with its examples of a save that passes and of a slug
  that another site has

- [x] 2.2 In `Site`, ask for the reload of the routes in `after_commit` (design D5). A create and a
  delete always ask. An update asks when the list of `PluginRoutes.get_sites` does not hold the
  stored slug. Verify: the examples of 1.2 pass, and the draw counts of
  `spec/requests/admin/settings/sites_controller_spec.rb` stay

## 3. Documentation

- [x] 3.1 Change the comment of `rescue_from ActiveRecord::RecordInvalid` in `AdminController`. Add
  the section "A refused site settings save stores nothing" and its at-a-glance row to
  `docs/upgrading-to-2.9.5.md`. Name the site settings save in the section on custom-field `values`
  in an unknown shape. Verify: the Markdown gate prints no line
- [x] 3.2 Add the section "A site asks for the reload of the routes after its commit" and its
  at-a-glance row to `docs/upgrading-to-2.9.5.md`. Verify: the Markdown gate prints no line

## 4. Verification and shipping

- [x] 4.1 Run `bin/rubocop -A`, `bin/rspec` on the new spec and the adjacent specs,
  `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`. Verify: each check
  passes
- [x] 4.2 Run `openspec validate --all --strict`. Verify: the change is valid
- [ ] 4.3 Open the PR, add the `CHANGELOG.md` entry with the link of the PR, and archive this change
  on the branch. Verify: `openspec validate --archived` passes
