# Tasks

## 1. Reproduce the theme install faults

- [x] 1.1 Add `spec/requests/theme_install_current_theme_spec.rb`. An administrator installs a theme
  through `GET /admin/appearances/themes?set=<theme>`. The `on_active` handler of that theme records
  `current_theme` and its argument, and it installs a plugin. Both themes register a handler for the
  after-install hook of that plugin. Verify: the example for `current_theme` and the example for the
  hook fail on the current code
- [x] 1.2 Add an example for the `on_inactive` handler of the theme before the install. Add an
  example for an `on_active` handler that also calls its handler directly. Verify: the `on_inactive`
  example passes on the current code (design D3), and the direct-call example fails on it
- [x] 1.3 Add examples for a request with a theme preview. An administrator opens the site with
  `ccc_theme_preview`, and a `front_before_load` handler of the preview theme calls
  `site_install_theme`. The handlers record `current_theme` during `on_inactive`, during `on_active`
  and after the install. A second example has an `on_active` handler that raises. Verify: the
  `on_inactive` record and the `on_active` record fail on the current code

## 2. Fix the theme install

- [x] 2.1 Add a private method to `CamaleonCms::SiteHelper` that takes a theme record and a block
  (design D1, D2, D5). It stores the record as the current theme of the request, sets
  `@_current_theme` aside, runs the block and restores the variable. Add a comment that says why
- [x] 2.2 Run the `on_active` hook of `site_install_theme` and the `on_inactive` hook of
  `site_uninstall_theme` through that method (design D3). Verify: the specs of 1.1 to 1.3 pass
- [x] 2.3 Add an at-a-glance row and a section under "Notes for theme & plugin developers" to
  `docs/upgrading-to-2.9.5.md`. They name the new current theme in `on_active` and the handler that
  can run two times (design D4). Verify: the anchor of the row resolves to the heading of the
  section, and the Markdown gate prints no line

## 3. Reproduce the site create faults

- [x] 3.1 Add `spec/requests/site_create_theme_hooks_spec.rb`. The installer creates the first site
  with the theme `new` (`POST /admin/installers/save`, as
  `spec/requests/security/installer_default_admin_hardening_spec.rb` does). The themes `new` and
  `default` register a handler for `plugin_after_install`, `on_inactive` and `on_active`. Verify: on
  the current code, the handler of `default` gets the plugin hooks and `on_inactive` of `default`
  runs. The site also has a theme record for `default`
- [x] 3.2 Add an example where the `plugin_after_install` handler of `new` stores an option on the
  theme record, and the `on_active` handler reads it. Verify: the example fails on the current code
- [x] 3.3 Add an example for a site create in the admin panel (`POST /admin/settings/sites`). The
  `on_inactive` handler of `default` does not run, and the theme record has the name of the theme
  config. Verify: both expectations fail on the current code
- [x] 3.4 Add an example for the install of the current theme of a site in the admin panel. The
  `on_inactive` handler runs, and then the `on_active` handler runs. Verify: the example passes on
  the current code

## 4. Fix the site create

- [x] 4.1 Store the `_theme` option in `site_after_install` before the default plugins are installed
  (design D6). Verify: the plugin hook expectations of 3.1 pass
- [x] 4.2 Move the steps of `site_install_theme` after the uninstall to a private method, and call
  that method from `site_after_install` (design D7). Verify: 3.1 to 3.4 pass, except the name
  expectation of 3.3
- [x] 4.3 Write the name of the theme config to the theme record in that private method (design
  D8). Do this only when the name of the record is empty or is the slug. Verify: 3.3 passes
- [x] 4.4 Add an at-a-glance row and a section to `docs/upgrading-to-2.9.5.md` for the site create.
  They name the theme that gets the hooks of the default plugins, the order before `on_active`, and
  the `on_inactive` hook that no longer runs. Verify: the anchor of the row resolves to the heading
  of the section, and the Markdown gate prints no line

## 5. Verification and shipping

- [x] 5.1 Run `bin/rubocop -A`, then the whole suite with `bin/rspec`, because the site factory
  calls `site_after_install`. Then run `bin/brakeman --no-pager` and
  `(cd spec/dummy && bin/rails zeitwerk:check)`. Verify: each check passes
- [x] 5.2 Run `openspec validate --all --strict`. Verify: the change is valid
- [x] 5.3 Open the PR, add the `CHANGELOG.md` entries with the link of the PR, and archive this
  change on the branch. Verify: `openspec validate --archived` passes

## 6. Fix the faults that the review found

- [x] 6.1 Set the theme preview aside for the whole site create (design D9). Give the preview theme
  back to `CurrentRequest` after each hook (design D5). Verify: the preview examples of
  `spec/requests/site_create_theme_hooks_spec.rb` and
  `spec/requests/theme_install_current_theme_spec.rb` pass
- [x] 6.2 Refuse an install of a theme that is not installed, before its first write (design D10).
  Add `spec/requests/unknown_theme_install_spec.rb` for the theme page and the install helpers.
  Verify: its examples pass
- [x] 6.3 Make the installer refuse an empty theme key. Make the installer and the site create of
  the admin panel check the default theme before they save the site (design D10). Verify: the
  installer and site create examples of `spec/requests/unknown_theme_install_spec.rb` pass
- [x] 6.4 Give the site of the request back in an `ensure` clause of `site_after_install` (design
  D9). Verify: the example of `spec/requests/site_create_theme_hooks_spec.rb` with a handler that
  raises passes
- [x] 6.5 Show the notice of the theme page after the redirect. Keep the typed domain and the
  selected theme when the installer form shows again. Verify: the examples of
  `spec/requests/admin/appearances/themes_controller_spec.rb`,
  `spec/requests/unknown_theme_install_spec.rb` and `spec/requests/admin/installers_controller_spec.rb`
  pass
- [x] 6.6 Name the changes of 6.1 to 6.5 in `docs/upgrading-to-2.9.5.md` or in `CHANGELOG.md`.
  Verify: the Markdown gate prints no line
