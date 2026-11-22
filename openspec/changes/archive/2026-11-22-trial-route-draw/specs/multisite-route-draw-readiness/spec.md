## ADDED Requirements

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
routes.

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

- **WHEN** each route file can be drawn, and code saves a site with a new slug
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

## MODIFIED Requirements

### Requirement: A site asks for the reload of the routes after the commit of its transaction

A site SHALL ask for the reload of the routes when it is created, when it gets a new slug and when
it is deleted. It SHALL ask with `PluginRoutes.request_reload`, after the commit of the transaction
that holds the change, and one time for that transaction. A transaction that rolls back SHALL ask
for no reload.

After a rollback, the list of `PluginRoutes.get_sites` MUST hold each site as stored.

A commit of a site update SHALL ask for no reload when the list of `PluginRoutes.get_sites` holds
the stored slug of that site. When the list is not loaded, the commit SHALL ask for no reload, and
it SHALL NOT load the list.

#### Scenario: A new slug outside a transaction

- **WHEN** code saves a site with a new slug, outside a transaction, while the list of
  `PluginRoutes.get_sites` is loaded
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

#### Scenario: A new slug while the list is not loaded

- **WHEN** code gives a site a new slug while the list of `PluginRoutes.get_sites` is not loaded
- **THEN** the routes are not drawn, and the commit does not load the list
- **AND** the next read of the list holds the new slug

#### Scenario: A delete that a transaction rolls back

- **WHEN** a transaction destroys a site, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the site

#### Scenario: A create that a transaction rolls back

- **WHEN** a transaction creates a site, and then rolls back
- **THEN** the list of `PluginRoutes.get_sites` holds no such site
- **AND** the app has no route of a post type of that site
