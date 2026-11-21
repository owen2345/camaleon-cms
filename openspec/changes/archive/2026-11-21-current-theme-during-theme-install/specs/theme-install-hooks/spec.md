## Purpose

A theme has an `on_active` hook and an `on_inactive` hook. This capability says which of them a
theme install and a site create run. It also says which theme is the current theme of the request
while they run.

## ADDED Requirements

### Requirement: A theme is the current theme while its install and uninstall hooks run

The install of a theme runs the `on_active` hook of that theme. While that hook runs, the current
theme of the request SHALL be the theme that is installed. A hook that a handler of `on_active` fires
SHALL go to the theme that is installed. That hook MUST NOT go to the theme before the install. The
`on_active` handler SHALL get the record of the theme that is installed as its argument.

The install over another theme first runs the `on_inactive` hook of the theme before the install.
While that hook runs, the current theme of the request SHALL be the theme before the install.

A user who can manage themes can preview a theme: the request then shows the site with that theme as
its current theme. The two rules above SHALL also hold in such a request. After each hook, the
current theme of that request SHALL be the preview theme again, also when a handler raises.

A handler SHALL run one time for each dispatch of its hook. A direct call of the handler from theme
code is no dispatch, so Camaleon SHALL NOT prevent a second run by such a call.

#### Scenario: The on_active handler reads the current theme

- **WHEN** an administrator installs a theme in the admin panel, and the `on_active` handler of that
  theme reads the current theme
- **THEN** the current theme is the theme that is installed, and it is the record that the handler
  got as its argument

#### Scenario: The on_active handler fires a hook that the installed theme handles

- **WHEN** the `on_active` handler of the theme that is installed installs a plugin
- **AND** both themes register a handler for the after-install hook of that plugin
- **THEN** the handler of the theme that is installed runs one time, and the handler of the theme
  before the install does not run

#### Scenario: The on_inactive handler reads the current theme

- **WHEN** an administrator installs a theme in the admin panel, and the `on_inactive` handler of the
  theme before the install reads the current theme
- **THEN** the current theme is the theme before the install

#### Scenario: The on_active handler also calls its handler directly

- **WHEN** the `on_active` handler installs a plugin, and it also calls its own handler of the
  after-install hook of that plugin directly
- **THEN** that handler runs two times: one time for the hook and one time for the direct call

#### Scenario: A request with a theme preview installs a theme

- **WHEN** a request previews a theme, and code of that request installs another theme
- **THEN** the `on_inactive` handler reads the theme before the install as the current theme
- **AND** the `on_active` handler reads the theme that is installed as the current theme
- **AND** after the install, the current theme is the preview theme, and the page shows that theme

#### Scenario: A handler raises in a request with a theme preview

- **WHEN** a request previews a theme, code of that request installs another theme, and the
  `on_active` handler raises
- **THEN** the caller gets that error, and the current theme of the request is the preview theme

### Requirement: The theme of a new site gets the hooks of the site create

The create of a site installs the default plugins and then the theme of the site. The theme of the
new site SHALL be the theme that the create names, before the first default plugin is installed. A
hook that the install of a default plugin fires SHALL go to that theme, and it MUST NOT go to another
theme.

The create SHALL make one theme record for the site, for the theme that the create names. That
record SHALL have the name that the config of the theme gives.

A theme preview is a theme of the site of the request. The rules above SHALL also hold in a request
with a theme preview. No hook of the create SHALL go to the preview theme. After the create, the
current theme of that request SHALL be the preview theme again, also when a handler raises.

After the create, the current site of the request SHALL be the site that it had before the create,
also when a handler raises.

#### Scenario: The installer creates a site with a theme that is not the default theme

- **WHEN** the installer creates the first site with a theme that is not the default theme
- **AND** that theme and the default theme register a handler for the `plugin_after_install` hook
- **THEN** the handler of the theme of the site runs one time for each default plugin
- **AND** the handler of the default theme does not run

#### Scenario: The new site has one theme record

- **WHEN** the installer creates the first site with a theme that is not the default theme
- **THEN** the site has one theme record, for the theme of the site
- **AND** that record has the name that the config of the theme gives

#### Scenario: The admin panel creates a site with the default theme

- **WHEN** an administrator creates a site in the admin panel
- **THEN** the theme record of the site has the name that the config of the default theme gives

#### Scenario: A request with a theme preview creates a site

- **WHEN** a request previews a theme, and code of that request creates a site
- **THEN** the hooks of the default plugin installs go to the theme of the new site, and not to the
  preview theme
- **AND** after the create, the current theme is the preview theme, and the page shows that theme

#### Scenario: A handler raises during a site create in a request with a theme preview

- **WHEN** a request previews a theme, code of that request creates a site, and a handler of a
  default plugin hook raises
- **THEN** the caller gets that error, the current site is the site of the request, and the current
  theme is the preview theme

### Requirement: The create of a site runs no on_inactive hook

A new site has no theme to uninstall. The create of a site SHALL run the `on_active` hook of the
theme of the site one time. It SHALL NOT run an `on_inactive` hook of any theme. A value that a
handler stores on the theme record during the create SHALL be on that record when `on_active` runs.

The install of a theme on a site that already has a theme SHALL still run the `on_inactive` hook of
the theme before the install. This includes the install of the theme that the site already has.

#### Scenario: A site create runs on_active only

- **WHEN** an administrator creates a site in the admin panel, and the theme of the site registers an
  `on_inactive` handler and an `on_active` handler
- **THEN** the `on_active` handler runs one time, and the `on_inactive` handler does not run

#### Scenario: A value that a plugin hook stored is there in on_active

- **WHEN** the installer creates a site, and a `plugin_after_install` handler of the theme of the
  site stores an option on the theme record
- **AND** the `on_inactive` handler of that theme destroys the theme record
- **THEN** the `on_active` handler reads that option from its argument

#### Scenario: An administrator installs the theme that the site already has

- **WHEN** an administrator installs the current theme of the site again in the admin panel
- **THEN** the `on_inactive` handler of that theme runs, and then its `on_active` handler runs

### Requirement: An install refuses a theme that is not installed

An install of a theme and a site create SHALL refuse a theme key that no installed theme has. The
refusal SHALL come before the first write, so the site keeps its theme and its theme records. The
install helpers SHALL raise `ArgumentError`. The theme page of the admin panel SHALL show an error.
The installer and the site create of the admin panel SHALL show their form again with an error,
and they SHALL create no site.

A site create with no theme of its own installs the default theme of the system config
(`default_template`). A host can name a theme there that is not installed, and the rules above
SHALL also hold for that theme.

#### Scenario: An administrator installs a theme that is not installed

- **WHEN** an administrator opens the theme page with a theme key that no installed theme has
- **THEN** the page shows an error, and the site keeps its theme and its theme records

#### Scenario: The installer gets a theme that is not installed

- **WHEN** the installer gets a theme key that no installed theme has
- **THEN** it shows its form again with an error, and it creates no site

#### Scenario: The default theme of the system config is not installed

- **WHEN** the system config names a default theme that is not installed
- **AND** an administrator creates a site in the admin panel, or the installer gets a request with
  no theme
- **THEN** the form shows again with an error, and the create makes no site

#### Scenario: Code installs a theme that is not installed

- **WHEN** code calls `site_install_theme` or `site_after_install` with such a key
- **THEN** the helper raises `ArgumentError` before its first write
