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
MUST NOT wait for the requests longer than `CamaleonCms::RouteReloadLock::WAIT_TIMEOUT` seconds.
After that time, it SHALL draw the routes and log a warning.

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

### Requirement: A reload waits a limited time for the thread that holds the lock

Code can hold the lock of `CamaleonCms::RouteReloadLock` for longer than a draw: a theme switch holds
it for its whole time. A reload of another thread MUST NOT wait for that thread longer than
`WAIT_TIMEOUT` seconds. Then it SHALL draw the routes with no lock and log a warning, and the lock
SHALL stay with the thread that holds it.

#### Scenario: Another thread holds the lock longer than the wait time

- **WHEN** a theme switch still holds the lock after `WAIT_TIMEOUT` seconds of a reload of another
  thread
- **THEN** the reload draws the routes and logs a warning
- **AND** a request that starts then still waits until the switch is done

### Requirement: A block can wait for the thread that holds the lock

`CamaleonCms::RouteReloadLock.exclusive(wait_for_holder: true)` SHALL NOT run its block with no
lock. It SHALL wait for the thread that holds the lock for `HOLDER_WAIT_TIMEOUT` seconds at most,
and then it SHALL raise `CamaleonCms::RouteReloadLock::WaitTimeout`. A theme switch takes the lock
this way. When its block starts while a request still runs, the warning SHALL name a theme switch,
not a reload.

#### Scenario: A block that waits for the thread that holds the lock

- **WHEN** a thread holds the lock, and another thread asks for it with `wait_for_holder: true`
- **THEN** the block of the second thread runs with the lock after the first thread is done
- **AND** when the first thread still holds the lock after `HOLDER_WAIT_TIMEOUT` seconds, the second
  thread gets `CamaleonCms::RouteReloadLock::WaitTimeout`, and its block does not run

#### Scenario: A theme switch starts while a request still runs

- **WHEN** a block with `wait_for_holder: true` waited for the requests for `WAIT_TIMEOUT` seconds,
  and a request still runs
- **THEN** the block runs with the lock
- **AND** the warning in the log names a theme switch, not a reload

### Requirement: The wait for the requests and the wait for the holder have a time each

The wait for the requests and the wait for the thread that holds the lock SHALL have a time each.
The wait for the requests SHALL count only the time in which no thread holds the lock. The wait for
that thread SHALL count only the time in which a thread holds the lock. So a reload waits for
2 x `WAIT_TIMEOUT` seconds at most. A block with `wait_for_holder: true` waits for `WAIT_TIMEOUT` +
`HOLDER_WAIT_TIMEOUT` seconds at most.

#### Scenario: A reload meets a thread that holds the lock, after a wait for a request

- **WHEN** a reload waits for a request, and a thread then takes the lock
- **THEN** the reload waits for that thread for `WAIT_TIMEOUT` seconds more at most
- **AND** only then it draws the routes with no lock

#### Scenario: A theme switch waits for a request, after a wait for the thread that holds the lock

- **WHEN** a block with `wait_for_holder: true` waited for the thread that holds the lock for longer
  than `WAIT_TIMEOUT` seconds
- **AND** a request still runs when that thread is done
- **THEN** the block waits for that request for `WAIT_TIMEOUT` seconds at most, before it runs

### Requirement: The lock counts each fiber as it counts each thread

A fiber server runs each request in a fiber, and such an app sets
`config.active_support.isolation_level` to `:fiber`. The lock SHALL then count each fiber as it
counts each thread: a share and the lock belong to one fiber.

#### Scenario: Two fibers of one thread

- **WHEN** the isolation level of the app is `:fiber`, and a fiber holds the lock
- **THEN** a block with `wait_for_holder: true` in another fiber of the same thread waits for that
  fiber
- **AND** a reload in a fiber waits for a request that runs in another fiber of the same thread

### Requirement: A draw that adds no route waits for the end of a block

`PluginRoutes.reload_once` SHALL run its block. In the block, `PluginRoutes.request_reload` SHALL
clear the caches of `PluginRoutes` at once. It SHALL leave the draw to the end of the block only when
the draw adds no route to the routes of the last reload. At the end of the block,
`PluginRoutes.reload_once` SHALL draw the routes one time when a call left a draw to it and the block
drew no routes after that call. It SHALL draw them also when the block raises an error.

#### Scenario: Two calls that add no route give one draw

- **WHEN** code in a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload` two times,
  and the database has no new post type, plugin, theme or language
- **THEN** the routes are not drawn in the block, and they are drawn one time at the end of the block

#### Scenario: A block that asks for no draw

- **WHEN** no code in a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload`
- **THEN** the routes are not drawn

#### Scenario: The caches are clear in the block

- **WHEN** code in a block calls `PluginRoutes.request_reload` and then reads a list that
  `PluginRoutes` caches, such as the enabled plugins of a site
- **THEN** the list comes from the database, not from the cache of before the call

#### Scenario: The block raises an error

- **WHEN** a call in a block left a draw to the end of the block, and the block then raises an error
- **THEN** the routes are drawn one time, and the caller gets the error

### Requirement: A draw that adds a route happens at once

`PluginRoutes.request_reload` SHALL draw the routes at once in a block when the draw adds a route. A
draw adds a route when the last reload did not have one of these:

- a post type with its present slug
- the route files of a plugin or a theme that a site has enabled
- a language of a site

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

### Requirement: Some calls draw the routes at once

A call before the first reload of the process SHALL draw at once. A call after a draw that raised an
error SHALL draw at once too. Outside such a block, `PluginRoutes.request_reload` SHALL reload the
routes at once. `PluginRoutes.reload` SHALL draw the routes at once, in the block too.

#### Scenario: A call before the first reload

- **WHEN** code in a block calls `PluginRoutes.request_reload` before the first reload of the process
- **THEN** the routes are drawn at once

#### Scenario: A call after a draw that raised an error

- **WHEN** a draw of the routes raised an error, and code in a block then calls
  `PluginRoutes.request_reload`
- **THEN** the routes are drawn at once

#### Scenario: A call outside a block

- **WHEN** code outside a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload`
- **THEN** `PluginRoutes.reload` draws the routes at once

#### Scenario: `PluginRoutes.reload` in a block

- **WHEN** a call in a block left a draw to the end of the block, and code in the block then calls
  `PluginRoutes.reload`
- **THEN** `PluginRoutes.reload` draws the routes at once, and the end of the block does not draw
  them again

### Requirement: A block does not change the draws of another block or thread

A block in another block SHALL leave the draw to the outer block. A block SHALL NOT change a reload
on another thread.

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

#### Scenario: An admin creates a second site

- **WHEN** an admin creates a site, and another site already has each default plugin and the theme
- **THEN** the routes are drawn 3 times, and they then have the route of each post type of the new
  site

#### Scenario: A create that fails

- **WHEN** an admin sends a site that is not valid
- **THEN** the routes are not drawn, and the admin sees the form again

### Requirement: The delete of a site draws the routes one time

The delete of a site SHALL draw the routes one time, in a `PluginRoutes.reload_once` block or not. A
post type that its site destroys SHALL ask for no draw. The site SHALL ask for the draw after its own
delete.

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

### Requirement: A site asks for the reload of the routes after the commit of its transaction

A site SHALL ask for the reload of the routes when it is created, when it gets a new slug and when
it is deleted. It SHALL ask with `PluginRoutes.request_reload`, after the commit of the transaction
that holds the change, and one time for that transaction. A transaction that rolls back SHALL ask
for no reload.

#### Scenario: A new slug outside a transaction

- **WHEN** code saves a site with a new slug, outside a transaction, while the list of
  `PluginRoutes.get_sites` is loaded
- **THEN** the routes are drawn one time, and the list of `PluginRoutes.get_sites` holds the new slug

#### Scenario: A second save after the new slug

- **WHEN** a transaction saves a site with a new slug, and then saves that site again, while the
  list of `PluginRoutes.get_sites` is loaded
- **THEN** the routes are not drawn in the transaction
- **AND** they are drawn one time after the commit

#### Scenario: A new slug and a save through another instance

- **WHEN** the site settings save stores a new slug, and its custom-field values then save the site
  through another instance, in one transaction
- **THEN** the list of `PluginRoutes.get_sites` holds the new slug after the commit

### Requirement: A rollback leaves the site list as stored

After a rollback, the list of `PluginRoutes.get_sites` MUST hold each site as stored.

#### Scenario: A new slug that a transaction rolls back

- **WHEN** a transaction saves a site with a new slug, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the stored slug

#### Scenario: A delete that a transaction rolls back

- **WHEN** a transaction destroys a site, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the site

#### Scenario: A create that a transaction rolls back

- **WHEN** a transaction creates a site, and then rolls back
- **THEN** the list of `PluginRoutes.get_sites` holds no such site
- **AND** the app has no route of a post type of that site

### Requirement: A site update asks for no reload when the list holds its stored slug

A commit of a site update SHALL ask for no reload when the list of `PluginRoutes.get_sites` holds
the stored slug of that site. When the list is not loaded, the commit SHALL ask for no reload, and
it SHALL NOT load the list.

#### Scenario: A save with no new slug

- **WHEN** code saves a new name of a site that is not the main site, and the list holds the stored
  slug of that site
- **THEN** the routes are not drawn

#### Scenario: A new slug while the list is not loaded

- **WHEN** code gives a site that is not the main site a new slug while the list of
  `PluginRoutes.get_sites` is not loaded
- **THEN** the routes are not drawn, and the commit does not load the list
- **AND** the next read of the list holds the new slug

### Requirement: The update of the main site asks for a reload when the default host changes

The main site is the exception. The routes hold the slug of the main site as their default host. The
commit of its update SHALL ask for the reload when the last reload drew another default host than
its stored slug. This rule holds also when the list is not loaded.

#### Scenario: A new slug of the main site in a transaction that draws the routes

- **WHEN** a transaction gives the main site a new slug and creates a post type, in the one order
  or in the other
- **THEN** the default host of the routes is the new slug after the commit

#### Scenario: A new slug of the main site while the list is not loaded

- **WHEN** code gives the main site a new slug while the list of `PluginRoutes.get_sites` is not
  loaded, after a reload that drew its old slug as the default host
- **THEN** the routes are drawn one time

### Requirement: A reload of the routes draws them on trial first

`PluginRoutes.reload` SHALL load the route files of Camaleon into an empty route set before it clears
the route set of the app. This trial SHALL read the data of the routes into a copy that only its
thread uses. When the trial raises an error, the reload SHALL raise `CamaleonCms::RouteDrawError`.
The message of that error SHALL name the error of the route file, and its cause SHALL be that error.
The route set of the app and the cached data of `PluginRoutes` MUST then stay as they were.

#### Scenario: The route file of a plugin raises an error

- **WHEN** the route file of an enabled plugin raises an error, and code calls `PluginRoutes.reload`
- **THEN** `PluginRoutes.reload` raises `CamaleonCms::RouteDrawError`, and its message names the
  error of the route file
- **AND** the app still has each route that it had before the call
- **AND** the list of `PluginRoutes.get_sites` and each value of `PluginRoutes.cache_variable` stay
  as they were

### Requirement: The draw of a reload uses the data of its trial

When the trial passes, the draw of the app route set SHALL read the data that the trial read. It
SHALL NOT read the sites from the database again. A reload MUST NOT draw the routes from data that is
older than the data of the last reload.

#### Scenario: A reload that passes

- **WHEN** code calls `PluginRoutes.reload`, and each route file can be drawn
- **THEN** the routes of the app are drawn one time
- **AND** the reload reads the sites from the database one time

### Requirement: A trial reads the database with no query cache

A trial SHALL read the database with no query cache. In a request, that cache holds the rows that
the request read before, and a write of another thread does not clear it. So a trial reads the rows
that another request stored before it.

#### Scenario: A trial in a request after a write of another request

- **WHEN** a request read the sites, another request then changes a site, and the first request
  reloads the routes
- **THEN** the trial of that reload reads the changed site

### Requirement: A fill of the shared route data uses no query cache

`PluginRoutes` keeps the site list and the lists of the enabled plugins for all threads. A read that
fills them SHALL use no query cache too. So a request that fills them after a clear gives each
thread the stored rows.

#### Scenario: A request fills the site list after a clear of another request

- **WHEN** a request read the sites, another request then changes a site and clears the site list,
  and the first request calls `PluginRoutes.get_sites`
- **THEN** the list holds the changed site

### Requirement: A check of the routes runs the trial alone

`PluginRoutes.check_routes` SHALL run the trial alone. It SHALL raise `CamaleonCms::RouteDrawError`
for a trial that fails. It MUST NOT change the route set of the app or the cached data of
`PluginRoutes`.

#### Scenario: A check with a draw that fails

- **WHEN** the route file of an enabled plugin raises an error, and code calls
  `PluginRoutes.check_routes`
- **THEN** the call raises `CamaleonCms::RouteDrawError`, and the routes of the app are not drawn

#### Scenario: A check with a draw that passes

- **WHEN** each route file can be drawn, and code calls `PluginRoutes.check_routes`
- **THEN** the call raises no error, and the routes of the app are not drawn
- **AND** the cached data of `PluginRoutes` stays as it was

### Requirement: A reload can take the trial of an earlier call

`PluginRoutes.trial_routes` SHALL run the trial as `check_routes` does, and return it.
`PluginRoutes.reload` and `PluginRoutes.request_reload` SHALL take that trial as `trial:`. A reload
with a trial SHALL draw from the data of the trial, with no trial of its own. When another reload drew
the routes after that trial, it SHALL run a trial again. It SHALL run a trial again also when the
transaction that was open at that trial rolled back.

#### Scenario: Another reload between the trial and the draw

- **WHEN** a reload of another thread draws the routes after the trial of a reload and before its
  draw
- **THEN** the reload runs its trial again, and it draws the routes from that data

#### Scenario: A trial whose transaction rolls back

- **WHEN** a transaction gives a site a new slug, calls `PluginRoutes.trial_routes`, and rolls back
- **AND** code gives that trial to `PluginRoutes.reload`
- **THEN** the reload runs a trial again, and the list of `PluginRoutes.get_sites` holds the stored
  slug

### Requirement: A reload runs a trial again after the commit of the trial transaction

A trial reads the rows as its transaction sees them, and another connection can commit a newer row.
So a reload SHALL run a trial again also after the commit of the outermost transaction that was
open at its trial. A reload in a later transaction SHALL run a trial again.

#### Scenario: A trial whose transaction commits

- **WHEN** a transaction calls `PluginRoutes.trial_routes` and commits, and another connection then
  stores a new name of a site
- **AND** code gives that trial to `PluginRoutes.reload`, with no open transaction
- **THEN** the reload runs a trial again, and the list of `PluginRoutes.get_sites` holds the new name

#### Scenario: A trial whose transaction commits, and a reload in a later transaction

- **WHEN** a transaction calls `PluginRoutes.trial_routes` and commits, and another connection then
  stores a new name of a site
- **AND** a later transaction of the same thread gives that trial to `PluginRoutes.reload`
- **THEN** the reload runs a trial again, and `PluginRoutes.get_sites` gives the new name in that
  transaction

### Requirement: The release of a savepoint does not make a reload run a trial again

A savepoint commits only with the transaction around it. So the release of a savepoint SHALL NOT make
a reload in that transaction run a trial again. When another reload drew the routes after the trial,
a reload in that transaction still SHALL run a trial again.

#### Scenario: A trial of a savepoint in an open transaction

- **WHEN** a savepoint in a transaction calls `PluginRoutes.trial_routes`, and the transaction then
  gives that trial to `PluginRoutes.reload`
- **THEN** the reload runs no trial, and it draws the routes from the data of the trial

### Requirement: A reload with a trial draws nothing when the routes already have the stored rows

A reload of the same thread, for example of a commit callback, can read its data after the trial.
It reads with no open transaction, and it can be the last draw of the routes. The reload with the
trial SHALL then draw nothing: the routes already have the stored rows. It SHALL draw nothing also after the commit
of the outermost transaction that was open at the trial, and in a later transaction. When the
transaction that was open at the trial rolled back, the reload SHALL run a trial again.

#### Scenario: A reload of the same thread between the trial and the draw

- **WHEN** a thread runs a trial, and then reloads the routes with no trial and no open transaction
- **AND** the thread gives the trial to `PluginRoutes.reload`, and no other thread drew the routes
- **THEN** that reload runs no trial, and it draws no routes

#### Scenario: The trial ran in a savepoint that rolled back

- **WHEN** a thread runs a trial in a savepoint, the savepoint rolls back, and its transaction commits
- **AND** the thread then reloads the routes with no trial, and gives the trial to `PluginRoutes.reload`
- **THEN** that reload runs a trial again, and it draws the routes

### Requirement: The trial loads no route file of another app or gem

The trial SHALL NOT load the route file of the host app, of a plugin gem or of another engine.

#### Scenario: A trial of a reload

- **WHEN** a reload runs its trial
- **THEN** the trial does not load the route file of the host app, of a plugin gem or of another
  engine

### Requirement: An admin request answers a route draw that fails as a refused save

When `CamaleonCms::RouteDrawError` reaches an admin controller, in a request that is not GET or
HEAD, the controller SHALL answer as it answers a refused save. The answer is a redirect back with
a flash error. For an XHR without the `cama_ajax_request` param, it is the message as text with a
422. The message SHALL name the error of the route file.

#### Scenario: A site settings save with a new slug

- **WHEN** the route file of an enabled plugin raises an error
- **AND** a site settings save carries a new slug
- **THEN** the response redirects back to the form with a flash error
- **AND** the flash error names the error of the route file, and it says that the change was not
  saved

#### Scenario: The same save by XHR

- **WHEN** the same save is an XHR without the `cama_ajax_request` param
- **THEN** the response is that message as text with a 422

### Requirement: The message of a route draw error says whether the change is saved

When a transaction was open on the thread at the failure, the message SHALL say that Camaleon did
not save the change. Otherwise it SHALL say that Camaleon kept the routes as they were. Camaleon
SHALL log the error. For a GET or HEAD request, the controller SHALL raise the error again.

#### Scenario: A change that is stored before the draw

- **WHEN** an admin saves the languages of a site, and the route file of an enabled plugin raises
  an error
- **THEN** the response redirects back with a flash error
- **AND** the flash error says that the routes stay as they were

### Requirement: The theme switch answers a route draw that fails with a redirect

The theme switch of the admin is a GET request. Its controller SHALL answer the error with a
redirect to the list of the themes and a flash error, and it SHALL log the error. That list draws no
routes. A failed trial in the transaction of the switch rolls the switch back. So the flash error
SHALL say that Camaleon did not save the change, and the site SHALL keep its old theme.

#### Scenario: A theme switch

- **WHEN** an admin switches the theme of a site, and the route file of an enabled plugin or theme
  raises an error
- **THEN** the response redirects to the list of the themes with a flash error
- **AND** the flash error says that the change was not saved, and the list answers with a 200
- **AND** the site keeps its old theme

#### Scenario: A theme switch whose hook fails the draw

- **WHEN** an admin switches the theme of a site, and a save of the `on_active` hook of the theme
  fails the draw in its transaction
- **THEN** the response redirects to the list of the themes with a flash error
- **AND** the flash error says that the change was not saved, and the site keeps its old theme
- **AND** the record that the hook saved is not stored

### Requirement: A route draw that fails after the commit of a theme switch keeps the switch

The draw after the commit of the switch runs a trial again. In a transaction of the caller, the
draw runs a trial again when another reload drew the routes after the trial of the switch. A change
outside the switch can fail that trial. The flash error then SHALL say that Camaleon kept the routes
as they were, and the theme stays switched.

#### Scenario: A change outside the switch fails the trial of the draw

- **WHEN** an admin switches the theme of a site, and a change outside the switch makes the trial of
  the draw after the commit fail
- **THEN** the flash error says that Camaleon kept the routes as they were
- **AND** the theme stays switched

### Requirement: The helper of the theme switch gives an error that is not in a transaction

When the draw after the commit of a theme switch fails, the helper of the theme switch SHALL give the
error with `in_transaction?` false. This holds also in a transaction of the caller, because the switch stays. A caller that lets that error through a
transaction of its own rolls the switch back, and the error does not say so.

#### Scenario: The draw after the switch fails in a transaction of the caller

- **WHEN** the draw after the commit of the switch fails in a transaction of the caller
- **THEN** the error that the helper gives has `in_transaction?` false

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

All threads share the site that `main_site` keeps. So the read for that site SHALL use no query
cache. The query cache of a request can hold the row from before a write of another request.

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

#### Scenario: A request that read the main site before a new slug of another request

- **WHEN** a request read the main site, and another request then gives the main site a new slug
- **AND** the first request reads `CamaleonCms::Site.main_site` again, or reloads the routes
- **THEN** `main_site` gives the new slug, and the routes get it as their default host

### Requirement: Data that PluginRoutes reads in a transaction stays with its thread

While a transaction is open on the connection of a thread, `PluginRoutes` SHALL keep the data that it
reads in a copy of that thread. The data is the site list and each value of
`PluginRoutes.cache_variable`. The other threads SHALL read the data from before the transaction.

#### Scenario: A new post type in a transaction

- **WHEN** a transaction creates a post type
- **THEN** the route helper of the post type exists in the transaction
- **AND** the site list that the other threads read does not hold the post type before the commit
- **AND** that list holds the post type after the commit

#### Scenario: A cached value in a transaction

- **WHEN** code in a transaction stores a value with `PluginRoutes.cache_variable`
- **THEN** the code reads the value back in the transaction
- **AND** the other threads do not read that value

### Requirement: A thread reads the committed or the stored data after the end of a transaction

After the commit, each thread SHALL read the committed data. After a rollback, the thread SHALL read
the stored data again. The routes of the app SHALL then be drawn again when a draw used the data of
that transaction.

#### Scenario: A new post type that a transaction rolls back

- **WHEN** a transaction creates a post type, and then rolls back
- **THEN** the app has no route of that post type
- **AND** the list of `PluginRoutes.get_sites` holds no such post type

#### Scenario: A read of a list that is not loaded

- **WHEN** a transaction gives a site a new slug, reads `PluginRoutes.get_sites` while the list is
  not loaded, and then rolls back
- **THEN** the list of `PluginRoutes.get_sites` holds the stored slug

### Requirement: A savepoint uses the data of its transaction

A savepoint in the transaction, such as a `requires_new` transaction, uses the data of the
transaction. After the rollback of a savepoint that used the data, the thread SHALL read the data
from the database again. This holds also for a savepoint in a savepoint that was released before the
rollback. The rollback also drops each value that the transaction stored with
`PluginRoutes.cache_variable` before the savepoint.

#### Scenario: A savepoint that rolls back

- **WHEN** a transaction stores a value with `PluginRoutes.cache_variable`
- **AND** a savepoint in it gives a site a new slug, reads `PluginRoutes.get_sites`, and rolls back
- **THEN** the list of `PluginRoutes.get_sites` in the transaction holds the stored slug
- **AND** `PluginRoutes.cache_variable` gives no value for the key that the transaction stored

### Requirement: A savepoint that reloads the routes gets data of its own

A savepoint that reloads the routes, or that asks for a reload, gets data of its own. After its
rollback, the thread SHALL read the data from the database again too. It MUST NOT read the shared
data while the transaction is open, because that data lacks the rows of the transaction.

#### Scenario: A savepoint that asks for a reload and rolls back

- **WHEN** a transaction creates a post type
- **AND** a savepoint in it calls `PluginRoutes.reload_after_commit`, and rolls back
- **THEN** the list of `PluginRoutes.get_sites` in the transaction holds the post type

### Requirement: Only some transactions count as open for the data of PluginRoutes

The transaction that the test fixtures open for each example SHALL NOT count as an open transaction
here. A `joinable: false` transaction, which no other transaction can join, SHALL count as an open
transaction here only inside a transaction that others can join.

#### Scenario: A transaction that no other transaction can join

- **WHEN** code in a transaction opens a `requires_new` transaction with `joinable: false`, stores a
  value there with `PluginRoutes.cache_variable`, and rolls that transaction back
- **THEN** `PluginRoutes.cache_variable` gives no value for that key, in each thread

#### Scenario: Only the transaction of the test fixtures is open

- **WHEN** only the transaction that the test fixtures open for an example is open, and code stores a
  value with `PluginRoutes.cache_variable`
- **THEN** `PluginRoutes` does not treat that transaction as open, and it keeps the value as it
  does with no transaction

### Requirement: A reload request can wait for the commit

`PluginRoutes.reload_after_commit` SHALL ask for a reload of the routes after the commit of the
transaction that is open on the thread. After the commit, it SHALL call `PluginRoutes.request_reload`,
one time for that transaction. After a rollback, it SHALL ask for no reload. With no open
transaction, it SHALL call `PluginRoutes.request_reload` at once.

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

### Requirement: A reload request clears the cached data of the thread at once

`PluginRoutes.reload_after_commit` SHALL clear the cached data of the thread at once, so that a later
read in the transaction comes from the database.

#### Scenario: A read after the request

- **WHEN** code in a transaction calls `PluginRoutes.reload_after_commit`, and then reads a list that
  `PluginRoutes` caches
- **THEN** the list comes from the database, not from the cached data of the thread

### Requirement: A reload request in a savepoint waits for the outermost transaction

A `requires_new` transaction is a savepoint of the transaction around it. Its request SHALL wait for
the commit of the outermost transaction. A rollback of that transaction SHALL drop the request.

#### Scenario: A request in a savepoint

- **WHEN** code in a `requires_new` transaction calls `PluginRoutes.reload_after_commit`, and the
  commit of the transaction around it is not over
- **THEN** the routes are not drawn
- **AND** they are drawn one time after that commit

### Requirement: The call after the commit comes right after a save of a site or a post type

The call after the commit SHALL come right after the commit when the transaction saved a site or a
post type. Else it SHALL come at the next call of `PluginRoutes`.

#### Scenario: A transaction that saved a site or a post type

- **WHEN** a transaction saves a site or a post type and calls `PluginRoutes.reload_after_commit`
- **THEN** `PluginRoutes.request_reload` runs right after the commit

#### Scenario: A transaction that saved no site and no post type

- **WHEN** a transaction saves no site and no post type, and calls `PluginRoutes.reload_after_commit`
- **THEN** `PluginRoutes.request_reload` runs at the next call of `PluginRoutes`

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
