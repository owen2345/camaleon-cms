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

### Requirement: A reload of the routes does not run while a request runs

`PluginRoutes.reload` SHALL wait until each other request that the app serves has its response,
before it clears and draws the route set. A request that starts while a reload runs or waits SHALL
wait until the draw is done. A request that reloads the routes SHALL NOT wait for itself. The reload
MUST NOT wait longer than `CamaleonCms::RouteReloadLock::WAIT_TIMEOUT` seconds: then it SHALL draw
the routes and log a warning.

#### Scenario: A reload waits for a request

- **WHEN** a request runs and `PluginRoutes.reload` starts
- **THEN** the route set is drawn only after the request has its response

#### Scenario: A request waits for a draw

- **WHEN** a draw of the routes runs and a request starts
- **THEN** the app gets the request only after the draw is done

#### Scenario: Two requests reload the routes at the same time

- **WHEN** two requests run, and each one calls `PluginRoutes.reload`
- **THEN** both reloads draw the routes, one after the other, and both requests finish

#### Scenario: A request runs longer than the wait time

- **WHEN** a request still runs after `WAIT_TIMEOUT` seconds of a reload
- **THEN** the reload draws the routes and logs a warning

### Requirement: A draw that adds no route waits for the end of a block

`PluginRoutes.reload_once` SHALL run its block. In the block, `PluginRoutes.request_reload` SHALL
clear the caches of `PluginRoutes` at once. It SHALL leave the draw to the end of the block only when
the draw adds no route to the routes of the last reload. At the end of the block,
`PluginRoutes.reload_once` SHALL draw the routes one time when a call left a draw to it and the block
drew no routes after that call. It SHALL draw them also when the block raises an error.

A draw adds a route when the last reload did not have one of these:

- a post type with its present slug
- the route files of a plugin or a theme that a site has enabled
- a language of a site

A call before the first reload of the process SHALL draw at once. A call after a draw that raised an
error SHALL draw at once too.

Outside such a block, `PluginRoutes.request_reload` SHALL reload the routes at once.
`PluginRoutes.reload` SHALL draw the routes at once, in the block too. A block in another block SHALL
leave the draw to the outer block. A block SHALL NOT change a reload on another thread.

#### Scenario: Two calls that add no route give one draw

- **WHEN** code in a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload` two times,
  and the database has no new post type, plugin, theme or language
- **THEN** the routes are not drawn in the block, and they are drawn one time at the end of the block

#### Scenario: A new post type in a block

- **WHEN** code in a block creates a post type
- **THEN** the routes are drawn at once, and the route helper of the post type exists in the block

#### Scenario: The first activation of a plugin in a block

- **WHEN** code in a block installs a plugin that no site had at the last reload
- **THEN** the routes are drawn before the `on_active` hook of the plugin runs

#### Scenario: A plugin that another site has

- **WHEN** code in a block installs a plugin that another site had at the last reload
- **THEN** the routes are not drawn before the end of the block

#### Scenario: A post type that the block deletes

- **WHEN** code in a block deletes a post type
- **THEN** the routes are not drawn before the end of the block

#### Scenario: A language that the block removes

- **WHEN** code in a block removes a language of a site, or deletes a site that has a language of its
  own
- **THEN** the routes are not drawn before the end of the block

#### Scenario: A block that asks for no draw

- **WHEN** no code in a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload`
- **THEN** the routes are not drawn

#### Scenario: A call after a draw that raised an error

- **WHEN** a draw of the routes raised an error, and code in a block then calls
  `PluginRoutes.request_reload`
- **THEN** the routes are drawn at once

#### Scenario: A call outside a block

- **WHEN** code outside a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload`
- **THEN** `PluginRoutes.reload` draws the routes at once

#### Scenario: The caches are clear in the block

- **WHEN** code in a block calls `PluginRoutes.request_reload` and then reads a list that
  `PluginRoutes` caches, such as the enabled plugins of a site
- **THEN** the list comes from the database, not from the cache of before the call

#### Scenario: `PluginRoutes.reload` in a block

- **WHEN** a call in a block left a draw to the end of the block, and code in the block then calls
  `PluginRoutes.reload`
- **THEN** `PluginRoutes.reload` draws the routes at once, and the end of the block does not draw
  them again

#### Scenario: The block raises an error

- **WHEN** a call in a block left a draw to the end of the block, and the block then raises an error
- **THEN** the routes are drawn one time, and the caller gets the error

#### Scenario: A block in a block

- **WHEN** a call in an inner block left a draw to the end of the block
- **THEN** the routes are drawn one time, at the end of the outer block

#### Scenario: Another thread

- **WHEN** a block runs on one thread, and another thread calls `PluginRoutes.request_reload`
- **THEN** the other thread draws the routes at once

### Requirement: The create and the delete of a site do not draw the routes for each step

The site create of the admin panel SHALL draw the routes one time for each default post type. It
SHALL draw them one more time for the site, its plugins and its theme, when the last reload had those
plugins and that theme. The last draw SHALL be done before the admin gets the response.
`site_after_install` SHALL draw the routes one time for its plugins and its theme, under the same
condition as the create.

The delete of a site SHALL draw the routes one time, in a `PluginRoutes.reload_once` block or not. A
post type that its site destroys SHALL ask for no draw. The site SHALL ask for the draw after its own
delete.

#### Scenario: An admin creates a second site

- **WHEN** an admin creates a site, and another site already has each default plugin and the theme
- **THEN** the routes are drawn 3 times, and they then have the route of each post type of the new
  site

#### Scenario: An admin deletes a site

- **WHEN** an admin deletes a site
- **THEN** the routes are drawn one time, and they then have no route of a post type of that site

#### Scenario: An admin deletes a site with a language of its own

- **WHEN** an admin deletes a site that has a language that no other site has
- **THEN** the routes are drawn one time

#### Scenario: No site has the default theme or the default language

- **WHEN** an admin deletes a site, and no site has the default theme or the default language
- **THEN** the routes are drawn one time

#### Scenario: A site delete outside a block

- **WHEN** code outside a `PluginRoutes.reload_once` block destroys a site
- **THEN** the routes are drawn one time, after the delete of the site

#### Scenario: A post type that is deleted with no delete of its site

- **WHEN** code outside a block destroys a post type, and not its site
- **THEN** the routes are drawn at once

#### Scenario: A create that fails

- **WHEN** an admin sends a site that is not valid
- **THEN** the routes are not drawn, and the admin sees the form again

### Requirement: A site asks for the reload of the routes after the commit of its transaction

A site SHALL ask for the reload of the routes when it is created, when it gets a new slug and when
it is deleted. It SHALL ask with `PluginRoutes.request_reload`, after the commit of the transaction
that holds the change, and one time for that transaction. A transaction that rolls back
SHALL ask for no reload. After a rollback, the list of `PluginRoutes.get_sites` MUST hold each site
as stored. A commit of a site update SHALL ask for no reload when the list of
`PluginRoutes.get_sites` holds the stored slug of that site.

#### Scenario: A new slug outside a transaction

- **WHEN** code saves a site with a new slug, outside a transaction
- **THEN** the routes are drawn one time, and the list of `PluginRoutes.get_sites` holds the new slug

#### Scenario: A new slug that a transaction rolls back

- **WHEN** a transaction saves a site with a new slug, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the stored slug

#### Scenario: A second save after the new slug

- **WHEN** a transaction saves a site with a new slug, and then saves that site again
- **THEN** the routes are not drawn in the transaction
- **AND** they are drawn one time after the commit

#### Scenario: A new slug and a save through another instance

- **WHEN** the site settings save stores a new slug, and its custom-field values then save the site
  through another instance, in one transaction
- **THEN** the list of `PluginRoutes.get_sites` holds the new slug after the commit

#### Scenario: A save with no new slug

- **WHEN** code saves a new name of a site, and the list holds the stored slug of that site
- **THEN** the routes are not drawn

#### Scenario: A delete that a transaction rolls back

- **WHEN** a transaction destroys a site, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the site
