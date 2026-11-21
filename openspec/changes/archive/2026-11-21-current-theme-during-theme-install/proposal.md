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

- The installer lets the user select a theme. The after-install hooks of the default plugins go to
  the default theme (`default_template`), not to the selected theme. The site also gets a theme
  record for the default theme, which it never used.
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
- Specs: a new request spec for the theme install in the admin panel and in a theme preview.
- Specs: a new request spec for the site create in the installer and in the admin panel.
- `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md`.
- Ecosystem: `docs/ai/ecosystem.md` lists no consumer of the three helpers. A theme whose
  `on_active` handler fires a hook now gets that hook. A theme that reads `current_theme` or a theme
  helper in that handler now gets its own theme. `camaleon_website` passes the theme record
  explicitly, and it keeps its behavior.
- Ecosystem, site create: no theme of the sibling checkouts registers a handler for the hook of a
  default plugin. No `on_inactive` handler of those themes needs a run on a new site (design D7).
