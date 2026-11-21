# Give the hooks of a theme install and of a site create to the correct theme

## Why

`site_install_theme` runs the `on_active` hook of the theme that it installs. A request keeps its
current theme after the first read of `current_theme`. An admin request reads it before the install,
so `current_theme` is still the theme before the install while the `on_active` handler runs.

`hooks_run` sends a hook to the enabled plugins and to the current theme. So a hook that the handler
fires goes to the theme before the install. An example is a theme that installs the ecommerce plugin
in its `on_active` handler. `plugin_install` fires `plugin_ecommerce_after_install`, and the handler
of the new theme for that hook never runs.

The theme helpers have the same fault in that handler. `theme_asset_path`, `theme_view` and
`theme_layout` with no theme name give the paths of the theme before the install.

The create of a site has two related faults. `site_after_install` installs the default plugins
before it stores the theme of the site:

- The installer lets the operator select a theme. The after-install hooks of the default plugins
  go to the default theme (`default_template`), not to the selected theme. The site also gets a
  theme record for the default theme, which it never used.
- Each site create runs an `on_inactive` hook before `on_active`, although a new site has no theme
  to uninstall. With the default theme selected, this is the `on_inactive` hook of that theme.

## What Changes

- `site_install_theme` makes the theme that it installs the current theme before it runs the
  `on_active` hook. The theme stays the current theme for the rest of the request.
- A hook that an `on_active` handler fires goes to the theme that is installed, and no longer to the
  theme before the install.
- The `on_active` handler still gets the theme record as its argument. A theme that passes that
  record to its own methods needs no change.
- Both hooks of the install also get their own theme in a request that previews another theme
  (`ccc_theme_preview`). The preview theme is the current theme again after each hook (design D5).
- `site_uninstall_theme` runs its `on_inactive` hook the same way. With no theme preview, the current
  theme is already the theme that is uninstalled, so nothing changes there (design D3).
- `site_after_install` stores the theme of the site before it installs the default plugins. So the
  after-install hooks of those plugins go to the theme of the site (design D6).
- **BREAKING**: `site_after_install` no longer runs an `on_inactive` hook. A theme switch and a
  reinstall in the admin panel still run it (design D7).
- The install gives the theme record the name of the theme config, when the record has its slug as
  its name (design D8).
- In a request with a theme preview, `site_after_install` sets the preview aside for the whole
  create. The hooks of the default plugins then go to the theme of the new site (design D9).
- After the create, `site_after_install` gives the request its own site back, also when a handler
  raises (design D9).
- An install refuses a theme key that no installed theme has, before its first write. The install
  helpers raise `ArgumentError`, and the theme page of the admin panel shows an error (design D10).
- The installer and the site create of the admin panel check the theme before they save the site.
  The installer also refuses an empty theme key. Each shows its form again with an error (design D10).
- The theme page of the admin panel shows its notice after an install. Before, `index` wrote the
  notice to `flash.now` and then redirected.
- When the installer form shows again, it keeps the domain that the operator typed and the theme
  that the operator selected.
- `docs/upgrading-to-2.9.5.md` tells a theme developer what changes. A handler can now run two
  times, when the `on_active` handler also calls it directly. On a site create, a handler of a
  default plugin hook now runs for the theme of the site, before `on_active`.

## Capabilities

### New Capabilities

- `theme-install-hooks`: the hooks that a theme install and a site create run. It also names the
  theme that gets a hook that they fire, and the current theme while they run.

### Modified Capabilities

None.

## Impact

- `app/helpers/camaleon_cms/site_helper.rb`: `site_after_install`, `site_install_theme`,
  `site_uninstall_theme` and four new private methods.
- `app/controllers/camaleon_cms/admin/appearances/themes_controller.rb`: the error for a theme that
  is not installed, and the notice after the redirect.
- `app/controllers/camaleon_cms/admin/installers_controller.rb` and
  `app/controllers/camaleon_cms/admin/settings/sites_controller.rb`: the theme check before the save.
  The installer form also keeps the typed domain.
- `app/views/camaleon_cms/admin/installers/form.html.erb`: the theme select keeps the selected theme.
- `config/locales/camaleon_cms/admin/en.yml`: the three error messages of the refusal.
- Specs: a new request spec for the theme install in the admin panel and in a theme preview.
- Specs: a new request spec for the site create in the installer and in the admin panel.
- Specs: a new request spec for the refusal of a theme that is not installed, and a new request spec
  for the installer form. The spec of the theme page gets an example for its notice.
- Specs: `spec/support/theme_hook_probes.rb` holds the hook probes that the specs of the theme
  install and of the site create share.
- `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md`.
- Ecosystem: `docs/ai/ecosystem.md` lists no consumer of the three helpers. A theme whose
  `on_active` handler fires a hook now gets that hook. A theme that reads `current_theme` or a theme
  helper in that handler now gets its own theme. `camaleon_website` passes the theme record
  explicitly, and it keeps its behavior.
- Ecosystem, site create: no theme of the sibling checkouts registers a handler for the hook of a
  default plugin. No `on_inactive` handler of those themes needs a run on a new site (design D7).
  The `demo_manage` plugin of `camaleon_website` calls `site_after_install` after it saves a demo
  site. Its default theme, `default`, is installed and has no `on_inactive` handler. So the refusal
  of D10 does not stop that create, and its hooks do not change.
