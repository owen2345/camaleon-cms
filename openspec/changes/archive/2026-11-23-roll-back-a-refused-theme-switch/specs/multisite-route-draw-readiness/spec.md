## MODIFIED Requirements

### Requirement: A reload of the routes draws them on trial first

`PluginRoutes.reload` SHALL load the route files of Camaleon into an empty route set before it clears
the route set of the app. This trial SHALL read the data of the routes into a copy that only its
thread uses. When the trial raises an error, the reload SHALL raise `CamaleonCms::RouteDrawError`.
The message of that error SHALL name the error of the route file, and its cause SHALL be that error.
The route set of the app and the cached data of `PluginRoutes` MUST then stay as they were.

When the trial passes, the draw of the app route set SHALL read the data that the trial read. It
SHALL NOT read the sites from the database again. A reload MUST NOT draw the routes from data that is
older than the data of the last reload.

A trial SHALL read the database with no query cache. In a request, that cache holds the rows that
the request read before, and a write of another thread does not clear it. So a trial reads the rows
that another request stored before it.

`PluginRoutes` keeps the site list and the lists of the enabled plugins for all threads. A read that
fills them SHALL use no query cache too. So a request that fills them after a clear gives each
thread the stored rows.

`PluginRoutes.check_routes` SHALL run the trial alone. It SHALL raise `CamaleonCms::RouteDrawError`
for a trial that fails. It MUST NOT change the route set of the app or the cached data of
`PluginRoutes`.

`PluginRoutes.trial_routes` SHALL run the trial as `check_routes` does, and return it.
`PluginRoutes.reload` and `PluginRoutes.request_reload` SHALL take that trial as `trial:`. A reload
with a trial SHALL draw from the data of the trial, with no trial of its own. When another reload drew
the routes after that trial, it SHALL run a trial again. It SHALL run a trial again also when the
transaction that was open at that trial rolled back.

A trial reads the rows as its transaction sees them, and another connection can commit a newer row.
So a reload SHALL run a trial again also after the commit of the outermost transaction that was
open at its trial. A savepoint commits only with the transaction around it. So the release of a
savepoint SHALL NOT make a reload in that transaction run a trial again. When another reload drew
the routes after the trial, a reload in that transaction still SHALL run a trial again. A reload in
a later transaction SHALL run a trial again.

The other reload can be a reload of the same thread, for example of a commit callback. That reload
can read its data after the trial, with no open transaction, and be the last draw of the routes. The
reload with the trial SHALL then draw nothing: the routes already have the stored rows. It SHALL
draw nothing also after the commit of the outermost transaction that was open at the trial, and in
a later transaction. When the transaction that was open at the trial rolled back, the reload SHALL
run a trial again instead.

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

- **WHEN** a reload of another thread draws the routes after the trial of a reload and before its
  draw
- **THEN** the reload runs its trial again, and it draws the routes from that data

#### Scenario: A trial in a request after a write of another request

- **WHEN** a request read the sites, another request then changes a site, and the first request
  reloads the routes
- **THEN** the trial of that reload reads the changed site

#### Scenario: A request fills the site list after a clear of another request

- **WHEN** a request read the sites, another request then changes a site and clears the site list,
  and the first request calls `PluginRoutes.get_sites`
- **THEN** the list holds the changed site

#### Scenario: A reload of the same thread between the trial and the draw

- **WHEN** a thread runs a trial, and then reloads the routes with no trial and no open transaction
- **AND** the thread gives the trial to `PluginRoutes.reload`, and no other thread drew the routes
- **THEN** that reload runs no trial, and it draws no routes

#### Scenario: A trial whose transaction rolls back

- **WHEN** a transaction gives a site a new slug, calls `PluginRoutes.trial_routes`, and rolls back
- **AND** code gives that trial to `PluginRoutes.reload`
- **THEN** the reload runs a trial again, and the list of `PluginRoutes.get_sites` holds the stored
  slug

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

#### Scenario: A trial of a savepoint in an open transaction

- **WHEN** a savepoint in a transaction calls `PluginRoutes.trial_routes`, and the transaction then
  gives that trial to `PluginRoutes.reload`
- **THEN** the reload runs no trial, and it draws the routes from the data of the trial

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
routes. A failed trial in the transaction of the switch rolls the switch back. So the flash error
SHALL say that Camaleon did not save the change, and the site SHALL keep its old theme.

The draw after the commit of the switch runs a trial again. In a transaction of the caller, the
draw runs a trial again when another reload drew the routes after the trial of the switch. A change
outside the switch can fail that trial.
The flash error then SHALL say that Camaleon kept the routes as they were, and the theme stays
switched. The helper SHALL give the error of that trial with `in_transaction?` false, also in a
transaction of the caller, because the switch stays. A caller that lets that error through a
transaction of its own rolls the switch back, and the error does not say so.

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
- **AND** the flash error says that the change was not saved, and the list answers with a 200
- **AND** the site keeps its old theme

#### Scenario: A theme switch whose hook fails the draw

- **WHEN** an admin switches the theme of a site, and a save of the `on_active` hook of the theme
  fails the draw in its transaction
- **THEN** the response redirects to the list of the themes with a flash error
- **AND** the flash error says that the change was not saved, and the site keeps its old theme
- **AND** the record that the hook saved is not stored

#### Scenario: A change that is stored before the draw

- **WHEN** an admin saves the languages of a site, and the route file of an enabled plugin raises
  an error
- **THEN** the response redirects back with a flash error
- **AND** the flash error says that the routes stay as they were

### Requirement: Data that PluginRoutes reads in a transaction stays with its thread

While a transaction is open on the connection of a thread, `PluginRoutes` SHALL keep the data that it
reads in a copy of that thread. The data is the site list and each value of
`PluginRoutes.cache_variable`. The other threads SHALL read the data from before the transaction.

After the commit, each thread SHALL read the committed data. After a rollback, the thread SHALL read
the stored data again. The routes of the app SHALL then be drawn again when a draw used the data of
that transaction.

A savepoint in the transaction, such as a `requires_new` transaction, uses the data of the
transaction. After the rollback of a savepoint that used the data, the thread SHALL read the data
from the database again. This holds also for a savepoint in a savepoint that was released before the
rollback. The rollback also drops each value that the transaction stored with
`PluginRoutes.cache_variable` before the savepoint.

A savepoint that reloads the routes, or that asks for a reload, gets data of its own. After its
rollback, the thread SHALL read the data from the database again too. It MUST NOT read the shared
data while the transaction is open, because that data lacks the rows of the transaction.

The transaction that the test fixtures open for each example is not an open transaction here. A
transaction that no other transaction can join (`joinable: false`) is an open transaction here when a
transaction that others can join is open around it.

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

#### Scenario: A savepoint that rolls back

- **WHEN** a transaction stores a value with `PluginRoutes.cache_variable`
- **AND** a savepoint in it gives a site a new slug, reads `PluginRoutes.get_sites`, and rolls back
- **THEN** the list of `PluginRoutes.get_sites` in the transaction holds the stored slug
- **AND** `PluginRoutes.cache_variable` gives no value for the key that the transaction stored

#### Scenario: A savepoint that asks for a reload and rolls back

- **WHEN** a transaction creates a post type
- **AND** a savepoint in it calls `PluginRoutes.reload_after_commit`, and rolls back
- **THEN** the list of `PluginRoutes.get_sites` in the transaction holds the post type

#### Scenario: A transaction that no other transaction can join

- **WHEN** code in a transaction opens a `requires_new` transaction with `joinable: false`, stores a
  value there with `PluginRoutes.cache_variable`, and rolls that transaction back
- **THEN** `PluginRoutes.cache_variable` gives no value for that key, in each thread

#### Scenario: A cached value in a transaction

- **WHEN** code in a transaction stores a value with `PluginRoutes.cache_variable`
- **THEN** the code reads the value back in the transaction
- **AND** the other threads do not read that value

### Requirement: A reload of the routes does not run while a request runs

`PluginRoutes.reload` SHALL wait until each other request that the app serves has its response,
before it clears and draws the route set. A request that starts while a reload runs or waits SHALL
wait until the draw is done. A request that reloads the routes SHALL NOT wait for itself. The reload
MUST NOT wait for the requests longer than `CamaleonCms::RouteReloadLock::WAIT_TIMEOUT` seconds:
then it SHALL draw the routes and log a warning.

Code can hold the lock for longer than a draw: a theme switch holds it for its whole time. A reload
of another thread MUST NOT wait for that thread longer than `WAIT_TIMEOUT` seconds either. Then it
SHALL draw the routes with no lock and log a warning, and the lock SHALL stay with the thread that
holds it.

`CamaleonCms::RouteReloadLock.exclusive(wait_for_holder: true)` SHALL NOT run its block with no
lock. It SHALL wait for the thread that holds the lock for `HOLDER_WAIT_TIMEOUT` seconds at most,
and then it SHALL raise `CamaleonCms::RouteReloadLock::WaitTimeout`. A theme switch takes the lock
this way. When its block starts while a request still runs, the warning SHALL name a theme switch,
not a reload.

The wait for the requests and the wait for the thread that holds the lock SHALL have a time each.
The wait for the requests SHALL count only the time in which no thread holds the lock. The wait for
that thread SHALL count only the time in which a thread holds the lock. So a reload waits for
2 x `WAIT_TIMEOUT` seconds at most. A block with `wait_for_holder: true` waits for `WAIT_TIMEOUT` +
`HOLDER_WAIT_TIMEOUT` seconds at most.

A fiber server runs each request in a fiber, and such an app sets
`config.active_support.isolation_level` to `:fiber`. The lock SHALL then count each fiber as it
counts each thread: a share and the lock belong to one fiber.

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

#### Scenario: Another thread holds the lock longer than the wait time

- **WHEN** a theme switch still holds the lock after `WAIT_TIMEOUT` seconds of a reload of another
  thread
- **THEN** the reload draws the routes and logs a warning
- **AND** a request that starts then still waits until the switch is done

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

#### Scenario: A reload meets a thread that holds the lock, after a wait for a request

- **WHEN** a reload waits for a request, and a thread then takes the lock
- **THEN** the reload waits for that thread for `WAIT_TIMEOUT` seconds more at most
- **AND** only then it draws the routes with no lock

#### Scenario: A theme switch waits for a request, after a wait for the thread that holds the lock

- **WHEN** a block with `wait_for_holder: true` waited for the thread that holds the lock for longer
  than `WAIT_TIMEOUT` seconds
- **AND** a request still runs when that thread is done
- **THEN** the block waits for that request for `WAIT_TIMEOUT` seconds at most, before it runs

#### Scenario: Two fibers of one thread

- **WHEN** the isolation level of the app is `:fiber`, and a fiber holds the lock
- **THEN** a block with `wait_for_holder: true` in another fiber of the same thread waits for that
  fiber
- **AND** a reload in a fiber waits for a request that runs in another fiber of the same thread

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
