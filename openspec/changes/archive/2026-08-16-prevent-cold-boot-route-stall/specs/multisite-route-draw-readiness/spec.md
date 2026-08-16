# multisite-route-draw-readiness

## Purpose

Building the route table is the first thing that must happen before any request is served. On a
multi-site install it must not scale with the number of sites, and it must complete before requests
are handled, so no request is ever served against a partially built table.

## ADDED Requirements

### Requirement: Route drawing does not scale with the number of sites

Drawing the route table SHALL read each site's configuration (options, languages, theme) and collect
its enabled plugins without issuing a database query per site. The per-site metadata reads SHALL be
served from an eager-loaded association, and the enabled-plugin slugs SHALL be collected in a single
query across all sites.

#### Scenario: Enabled plugins are resolved in one query

- **WHEN** the enabled plugins across all sites are collected during route drawing
- **THEN** their slugs are read with a single `parent_id IN (...)` query, not one query per site

#### Scenario: Site metadata is read from memory

- **WHEN** route drawing reads sites through `PluginRoutes.get_sites`
- **THEN** each site's metas association is already loaded, so per-site option, language and theme
  reads issue no additional query

#### Scenario: An empty site list issues no plugin query

- **WHEN** there are no sites (for example the database is not yet available during early boot)
- **THEN** collecting enabled plugin slugs issues no query and returns an empty result

### Requirement: The route table is ready before the first request

When Rails would otherwise draw routes lazily on the first request — development, where
`config.eager_load` is false — the route table SHALL be drawn during boot instead, so no request is
served against a partially built table. The boot-time draw SHALL be guarded so it never aborts boot
when the database is unavailable.

#### Scenario: Routes are drawn at boot in development

- **WHEN** the application boots with `config.eager_load` false and the database installed
- **THEN** the route table is drawn during initialization, before the first request

#### Scenario: The boot-time draw is skipped when routes are already eager-loaded

- **WHEN** the application boots with `config.eager_load` true, where routes are drawn at boot already
- **THEN** no additional draw is performed

#### Scenario: The boot-time draw never aborts boot

- **WHEN** the database is unavailable during boot (migrations, asset precompile, a fresh install)
- **THEN** the draw is skipped and boot continues without raising
