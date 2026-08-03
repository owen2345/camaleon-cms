## Purpose

Define how helper classes declared by installed plugins and themes are aggregated and registered on the controller chain. The `helpers` key of an app's config is optional, and the aggregated helper lists must contain only helper class name strings that are safe to constantize.

## Requirements

### Requirement: The helpers key is optional in plugin and theme configs

The system SHALL treat the `helpers` key of an installed plugin's or theme's config as optional:
an app that omits the key, or declares an empty list, SHALL NOT affect helper registration for
other apps and SHALL NOT prevent the application from booting or serving requests.

#### Scenario: An installed plugin without helpers does not break the install

- **WHEN** an installed plugin's `config.json` has no `helpers` key
- **AND** `CamaleonCms::CamaleonController` includes every entry of `PluginRoutes.all_helpers`
  at class-body load
- **THEN** class loading completes without error

### Requirement: PluginRoutes helper lists contain only helper class names

`PluginRoutes.all_helpers` and `PluginRoutes.site_plugin_helpers` SHALL return arrays containing
only the helper class name strings declared by installed apps — never `nil` — so every entry is
safe to `constantize`.

#### Scenario: Apps without helpers are omitted from the aggregate list

- **WHEN** the installed apps are one with no `helpers` key, one with `helpers: []`, and one
  declaring `helpers: ["CamaleonCms::CamaleonHelper"]`
- **THEN** `PluginRoutes.all_helpers` returns exactly `["CamaleonCms::CamaleonHelper"]`

#### Scenario: Site-scoped helper list is nil-free

- **WHEN** a site's enabled apps include one without a `helpers` key
- **THEN** `PluginRoutes.site_plugin_helpers(site)` contains no `nil` entries
