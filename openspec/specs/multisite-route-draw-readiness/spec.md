# multisite-route-draw-readiness Specification

## Purpose
Building the route table is the first thing that must happen before any request is served. On a
multi-site install it must not scale with the number of sites, and it must complete before requests
are handled, so no request is ever served against a partially built table.
## Requirements
### Requirement: Route drawing does not scale with the number of sites

Drawing the route table SHALL read each site's configuration (options, languages, theme) and its post
types, and collect its enabled plugins, without issuing a database query per site. The per-site
metadata and post-type reads SHALL be served from eager-loaded associations, and the enabled-plugin
slugs SHALL be collected in a single query across all sites.

#### Scenario: Enabled plugins are resolved in one query

- **WHEN** the enabled plugins across all sites are collected during route drawing
- **THEN** their slugs are read with a single query across all sites, not one query per site

#### Scenario: Site metadata is read from memory

- **WHEN** route drawing reads sites through `PluginRoutes.get_sites`
- **THEN** each site's metas association is already loaded, so per-site option, language and theme
  reads issue no additional query

#### Scenario: Site post types are read from memory

- **WHEN** frontend route drawing reads each site's post types through `PluginRoutes.get_sites`
- **THEN** each site's post_types association is already loaded, so the post-type route loop issues no
  additional query per site

#### Scenario: An empty site list issues no plugin query

- **WHEN** there are no sites (for example the database is not yet available during early boot)
- **THEN** collecting enabled plugin slugs issues no query and returns an empty result

### Requirement: The route table is ready before the first request

When Rails would otherwise draw routes lazily on the first request — development, where
`config.eager_load` is false — the route table SHALL be drawn during boot instead, so the expensive
multi-site draw completes at boot and the first request never races a cold draw. The boot-time draw
SHALL be wired so it does not perturb Rails' initializer ordering or the asset load path, and SHALL be
guarded so it never aborts boot when the database is unavailable.

#### Scenario: Routes are drawn at boot in development

- **WHEN** the application boots with `config.eager_load` false and the database installed
- **THEN** the route table is drawn during initialization, before the first request is served

#### Scenario: The boot draw does not perturb the asset load path

- **WHEN** the boot-time draw is wired into the engine
- **THEN** it is registered as an `after_initialize` callback rather than a named initializer anchored
  to a late boot hook, so it does not reorder Rails' initializer graph or drop engine asset load paths
  (which would raise `AssetNotPrecompiledError` for plugin/theme and core assets)

#### Scenario: The boot-time draw is skipped when routes are already eager-loaded

- **WHEN** the application boots with `config.eager_load` true, where routes are drawn at boot already
- **THEN** no additional draw is performed

#### Scenario: The boot-time draw is skipped during a database Rake task

- **WHEN** the process is running a `db:` Rake task (for example `db:migrate`), whose schema is
  mid-change and which serves no request
- **THEN** the eager draw is skipped and routes are left to be drawn lazily

#### Scenario: The boot-time draw never aborts boot on database unavailability

- **WHEN** the database is unavailable during boot (migrations, asset precompile, a fresh install)
- **THEN** the draw is skipped and boot continues without raising

#### Scenario: A genuine route error is not swallowed

- **WHEN** the boot-time draw fails for a reason other than database unavailability (for example a
  route definition error)
- **THEN** the error surfaces rather than being logged and hidden

