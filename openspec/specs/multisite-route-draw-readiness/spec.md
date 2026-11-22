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
that holds the change, and one time for that transaction. A transaction that rolls back SHALL ask
for no reload.

After a rollback, the list of `PluginRoutes.get_sites` MUST hold each site as stored.

A commit of a site update SHALL ask for no reload when the list of `PluginRoutes.get_sites` holds
the stored slug of that site. When the list is not loaded, the commit SHALL ask for no reload, and
it SHALL NOT load the list.

The main site is the exception. The routes hold the slug of the main site as their default host. The
commit of its update SHALL ask for the reload when the last reload drew another default host than
its stored slug. This rule holds also when the list is not loaded.

#### Scenario: A new slug outside a transaction

- **WHEN** code saves a site with a new slug, outside a transaction, while the list of
  `PluginRoutes.get_sites` is loaded
- **THEN** the routes are drawn one time, and the list of `PluginRoutes.get_sites` holds the new slug

#### Scenario: A new slug that a transaction rolls back

- **WHEN** a transaction saves a site with a new slug, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the stored slug

#### Scenario: A second save after the new slug

- **WHEN** a transaction saves a site with a new slug, and then saves that site again, while the
  list of `PluginRoutes.get_sites` is loaded
- **THEN** the routes are not drawn in the transaction
- **AND** they are drawn one time after the commit

#### Scenario: A new slug and a save through another instance

- **WHEN** the site settings save stores a new slug, and its custom-field values then save the site
  through another instance, in one transaction
- **THEN** the list of `PluginRoutes.get_sites` holds the new slug after the commit

#### Scenario: A save with no new slug

- **WHEN** code saves a new name of a site, and the list holds the stored slug of that site
- **THEN** the routes are not drawn

#### Scenario: A new slug while the list is not loaded

- **WHEN** code gives a site that is not the main site a new slug while the list of
  `PluginRoutes.get_sites` is not loaded
- **THEN** the routes are not drawn, and the commit does not load the list
- **AND** the next read of the list holds the new slug

#### Scenario: A new slug of the main site in a transaction that draws the routes

- **WHEN** a transaction gives the main site a new slug and creates a post type, in the one order
  or in the other
- **THEN** the default host of the routes is the new slug after the commit

#### Scenario: A new slug of the main site while the list is not loaded

- **WHEN** code gives the main site a new slug while the list of `PluginRoutes.get_sites` is not
  loaded, after a reload that drew its old slug as the default host
- **THEN** the routes are drawn one time

#### Scenario: A delete that a transaction rolls back

- **WHEN** a transaction destroys a site, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the site

#### Scenario: A create that a transaction rolls back

- **WHEN** a transaction creates a site, and then rolls back
- **THEN** the list of `PluginRoutes.get_sites` holds no such site
- **AND** the app has no route of a post type of that site

### Requirement: A reload of the routes draws them on trial first

`PluginRoutes.reload` SHALL load the route files of Camaleon into an empty route set before it clears
the route set of the app. This trial SHALL read the data of the routes into a copy that only its
thread uses. When the trial raises an error, the reload SHALL raise `CamaleonCms::RouteDrawError`.
The message of that error SHALL name the error of the route file, and its cause SHALL be that error.
The route set of the app and the cached data of `PluginRoutes` MUST then stay as they were.

When the trial passes, the draw of the app route set SHALL read the data that the trial read. It
SHALL NOT read the sites from the database again. A reload MUST NOT draw the routes from data that is
older than the data of the last reload.

`PluginRoutes.check_routes` SHALL run the trial alone. It SHALL raise `CamaleonCms::RouteDrawError`
for a trial that fails. It MUST NOT change the route set of the app or the cached data of
`PluginRoutes`.

The trial does not load the route file of the host app, of a plugin gem or of another engine.

#### Scenario: The route file of a plugin raises an error

- **WHEN** the route file of an enabled plugin raises an error, and code calls `PluginRoutes.reload`
- **THEN** `PluginRoutes.reload` raises `CamaleonCms::RouteDrawError`, and its message names the
  error of the route file
- **AND** the app still has each route that it had before the call
- **AND** the list of `PluginRoutes.get_sites` and each value of `PluginRoutes.cache_variable` stay
  as they were

#### Scenario: A reload that passes

- **WHEN** code calls `PluginRoutes.reload`, and each route file can be drawn
- **THEN** the routes of the app are drawn one time
- **AND** the reload reads the sites from the database one time

#### Scenario: Another reload between the trial and the draw

- **WHEN** another reload draws the routes after the trial of a reload and before its draw
- **THEN** the reload runs its trial again, and it draws the routes from that data

#### Scenario: A check with a draw that fails

- **WHEN** the route file of an enabled plugin raises an error, and code calls
  `PluginRoutes.check_routes`
- **THEN** the call raises `CamaleonCms::RouteDrawError`, and the routes of the app are not drawn

#### Scenario: A check with a draw that passes

- **WHEN** each route file can be drawn, and code calls `PluginRoutes.check_routes`
- **THEN** the call raises no error, and the routes of the app are not drawn
- **AND** the cached data of `PluginRoutes` stays as it was

### Requirement: An admin request answers a route draw that fails as a refused save

When `CamaleonCms::RouteDrawError` reaches an admin controller, in a request that is not GET or
HEAD, the controller SHALL answer as it answers a refused save. The answer is a redirect back with
a flash error. For an XHR without the `cama_ajax_request` param, it is the message as text with a
422. The message SHALL name the error of the route file.

When a transaction was open on the thread at the failure, the message SHALL say that Camaleon did
not save the change. Otherwise it SHALL say that Camaleon kept the routes as they were. Camaleon
SHALL log the error. For a GET or HEAD request, the controller SHALL raise the error again.

The theme switch of the admin is a GET request. Its controller SHALL answer the error with a
redirect to the list of the themes and a flash error, and it SHALL log the error. That list draws no
routes. The flash error SHALL say that Camaleon kept the routes as they were, also when a
transaction was open at the failure. The switch stores the theme before the `on_active` hook of
the theme, so the theme stays switched.

#### Scenario: A site settings save with a new slug

- **WHEN** the route file of an enabled plugin raises an error
- **AND** a site settings save carries a new slug
- **THEN** the response redirects back to the form with a flash error
- **AND** the flash error names the error of the route file, and it says that the change was not
  saved

#### Scenario: The same save by XHR

- **WHEN** the same save is an XHR without the `cama_ajax_request` param
- **THEN** the response is that message as text with a 422

#### Scenario: A theme switch

- **WHEN** an admin switches the theme of a site, and the route file of an enabled plugin or theme
  raises an error
- **THEN** the response redirects to the list of the themes with a flash error
- **AND** the flash error says that the routes stay as they were, and the list answers with a 200

#### Scenario: A theme switch whose hook fails the draw

- **WHEN** an admin switches the theme of a site, and a save of the `on_active` hook of the theme
  fails the draw in its transaction
- **THEN** the response redirects to the list of the themes with a flash error
- **AND** the flash error says that the routes stay as they were, and the site has the new theme

#### Scenario: A change that is stored before the draw

- **WHEN** an admin saves the languages of a site, and the route file of an enabled plugin raises
  an error
- **THEN** the response redirects back with a flash error
- **AND** the flash error says that the routes stay as they were

### Requirement: A site checks the routes in its transaction

A site SHALL call `PluginRoutes.check_routes` in the transaction that gives it a new slug, and in the
transaction that deletes it. When the check raises an error, that transaction SHALL roll back. The
route set of the app and the cached data of `PluginRoutes` MUST then stay as they were.

The create of a site needs no check of its own. Each post type of the site reloads the routes in
that transaction, and that reload starts with a trial.

#### Scenario: A site settings save with a new slug when the routes cannot be drawn

- **WHEN** the route file of an enabled plugin raises an error
- **AND** a site settings save carries a new slug
- **THEN** the save stores nothing, and the site keeps its slug
- **AND** the app still has each route that it had before the save

#### Scenario: A delete when the routes cannot be drawn

- **WHEN** the route file of an enabled plugin raises an error, and code destroys a site
- **THEN** the site is not deleted, and the app still has each route that it had before

#### Scenario: A new slug when the routes can be drawn

- **WHEN** each route file can be drawn, and code saves a site with a new slug while the list of
  `PluginRoutes.get_sites` is loaded
- **THEN** the slug is stored, and the routes of the app are drawn one time, after the commit

### Requirement: The main site follows the stored sites

`CamaleonCms::Site.main_site` SHALL return the site with the lowest id. After a reload of the routes,
and after the commit of a site, it SHALL read that site from the database again. A read in a trial
draw, or while a transaction is open, MUST NOT keep the site that it read.

#### Scenario: A new slug of the main site

- **WHEN** code gives the main site a new slug
- **THEN** `CamaleonCms::Site.main_site.slug` is the new slug

#### Scenario: Site ids that do not start at 1

- **WHEN** the lowest id of a site is not 1
- **THEN** `CamaleonCms::Site.main_site` is the site with that id

#### Scenario: The create of the first site rolls back

- **WHEN** no site exists, and a transaction creates a site, reads `CamaleonCms::Site.main_site` and
  then rolls back
- **THEN** `CamaleonCms::Site.main_site` returns nil after the rollback

### Requirement: Data that PluginRoutes reads in a transaction stays with its thread

While a transaction is open on the connection of a thread, `PluginRoutes` SHALL keep the data that it
reads in a copy of that thread. The data is the site list and each value of
`PluginRoutes.cache_variable`. The other threads SHALL read the data from before the transaction.

After the commit, each thread SHALL read the committed data. After a rollback, the thread SHALL read
the stored data again. The routes of the app SHALL then be drawn again when a draw used the data of
that transaction.

The transaction that the test fixtures open for each example is not an open transaction here.

#### Scenario: A new post type in a transaction

- **WHEN** a transaction creates a post type
- **THEN** the route helper of the post type exists in the transaction
- **AND** the site list that the other threads read does not hold the post type before the commit
- **AND** that list holds the post type after the commit

#### Scenario: A new post type that a transaction rolls back

- **WHEN** a transaction creates a post type, and then rolls back
- **THEN** the app has no route of that post type
- **AND** the list of `PluginRoutes.get_sites` holds no such post type

#### Scenario: A read of a list that is not loaded

- **WHEN** a transaction gives a site a new slug, reads `PluginRoutes.get_sites` while the list is
  not loaded, and then rolls back
- **THEN** the list of `PluginRoutes.get_sites` holds the stored slug

#### Scenario: A cached value in a transaction

- **WHEN** code in a transaction stores a value with `PluginRoutes.cache_variable`
- **THEN** the code reads the value back in the transaction
- **AND** the other threads do not read that value

### Requirement: A reload request can wait for the commit

`PluginRoutes.reload_after_commit` SHALL ask for a reload of the routes after the commit of the
transaction that is open on the thread. It SHALL clear the cached data of the thread at once, so that
a later read in the transaction comes from the database. After the commit, it SHALL call
`PluginRoutes.request_reload`, one time for that transaction. After a rollback, it SHALL ask for no
reload. With no open transaction, it SHALL call `PluginRoutes.request_reload` at once.

A `requires_new` transaction is a savepoint of the transaction around it. Its request SHALL wait for
the commit of the outermost transaction. A rollback of that transaction SHALL drop the request.

The call after the commit SHALL come right after the commit when the transaction saved a site or a
post type. Else it SHALL come at the next call of `PluginRoutes`.

#### Scenario: A request with no open transaction

- **WHEN** code outside a transaction calls `PluginRoutes.reload_after_commit`
- **THEN** the routes are drawn at once

#### Scenario: A request in a transaction that commits

- **WHEN** code in a transaction calls `PluginRoutes.reload_after_commit` two times
- **THEN** the routes are not drawn in the transaction
- **AND** they are drawn one time after the commit

#### Scenario: A request in a transaction that rolls back

- **WHEN** code in a transaction calls `PluginRoutes.reload_after_commit`, and the transaction rolls
  back
- **THEN** the routes are not drawn

#### Scenario: A request in a savepoint

- **WHEN** code in a `requires_new` transaction calls `PluginRoutes.reload_after_commit`, and the
  commit of the transaction around it is not over
- **THEN** the routes are not drawn
- **AND** they are drawn one time after that commit

### Requirement: A post type draws the routes in its transaction only for a create

A post type SHALL ask for the draw with `PluginRoutes.request_reload` in the transaction that creates
it. So the route helper of the post type exists for code later in that transaction. For a new slug
and for a delete, the post type SHALL ask with `PluginRoutes.reload_after_commit`. A post type that
its site destroys SHALL ask for no draw.

#### Scenario: A new slug in a transaction

- **WHEN** a transaction saves a post type with a new slug
- **THEN** the routes are not drawn in the transaction
- **AND** they are drawn one time after the commit, and the app then has the route of the new slug

#### Scenario: A new slug outside a transaction

- **WHEN** code saves a post type with a new slug, outside a transaction
- **THEN** the routes are drawn one time, right after the save

#### Scenario: A delete that a transaction rolls back

- **WHEN** a transaction destroys a post type, and not its site, and then rolls back
- **THEN** the routes are not drawn, and the app still has the route of the post type
