# Design

## Context

See `proposal.md`, "Why". `PostsController#save_post_with_fields` is the model in Camaleon. It
writes a post with its metas, field values and options in one transaction, so a refused value
stores nothing.

Two parts of Camaleon already follow a rollback. `CamaleonCms::Metas` refills the options of a
record in memory when the transaction of a write rolls back. In a transaction, `PluginRoutes` keeps
the data of a reload with the thread of that transaction. It drops that data after a rollback
(`CamaleonCms::RouteTransactionData`).

## Goals / Non-Goals

**Goals:**

- A switch that raises keeps the old theme key, the theme records and every row that the hooks
  wrote, as they were before the switch.
- The front page renders the old theme after such a switch.
- The caller gets the error, and the answers of the admin panel stay as they are.

**Non-Goals:**

- A change that a hook makes outside the database (D5).
- `site_after_install`. A site create does not call `site_install_theme`: it installs its theme
  with `cama_activate_theme`.

## Decisions

**D1. One savepoint holds the switch.** `site_install_theme` calls
`ActiveRecord::Base.transaction(requires_new: true)` around `site_uninstall_theme` and
`cama_activate_theme`. The check of the key (`cama_require_theme`) stays before it, because the
check writes nothing.

- With no transaction of a caller, this is a real transaction.
- In a transaction of a caller, it is a savepoint. A caller that rescues the error can go on with
  its own transaction. A transactional spec gets the same savepoint.
- Rails 7.1 and later open no savepoint in a transaction of the caller that ran no statement: a
  failed switch restarts that transaction. On SQLite with Rails 8.1, the caller can then get an
  internal error of Rails, not the error of the hook. So the helper marks that transaction as dirty
  first, with `CamaleonCms::CallerTransaction.force_savepoint`. `_cama_write_field_values` uses the
  same method.

- *Alternative: undo each step in a `rescue`.* Rejected: the hooks of a theme write rows that
  Camaleon does not know.

**D2. PluginRoutes settles at once.** A hook can install a plugin, and `plugin_install` draws the
routes from the rows of the switch. After the rollback, `site_install_theme` calls
`PluginRoutes.settle_route_data(quiet: true)`. The settle step drops the data of the switch and
draws the routes again when a draw used that data.

The next read of `PluginRoutes` does the same, but the call does it before the caller gets the
error. `quiet` does not apply to the draw after a rollback, which never raises. The call is in the
`ensure` block of D3, so it runs for an exception of any class.

**D3. The request gets its old current theme back.** `cama_with_current_theme` stores the new theme
in `CurrentRequest.frontend_current_theme` for the `on_active` hook, and the new theme stays there
after the hook. `site_install_theme` stores the old value before the savepoint and writes it back
when a step raises. `cama_without_preview_theme` already gives a theme preview
(`@_current_theme`) back. The option `_theme` of `current_site` needs no step: `CamaleonCms::Metas`
refills the options in memory after the rollback.

The helper writes the value back in an `ensure` block. Rails rolls the switch back for an exception
of any class, for example a timeout of the caller.

The request keeps the current theme that it read at its start. A failed switch gives that theme
back, also when another switch stored another theme after that read (D10).

With no transaction of the caller, the rollback turns each record that the switch created into a new
record. The association that created the record keeps it. The next save of the site then stored the
theme and the plugins of the switch again. In a transaction of the caller, only a record that the
switch saved one time is a new record again. A record that it saved more than one time keeps its id,
with no row in the database. So the helper resets the `themes` and the `plugins` associations of the
current site, which `cama_activate_theme` and `plugin_install` fill.

A switch can fail before its transaction, for example for a transaction isolation level of the pool.
It then filled no association, and a caller can hold unsaved records there. So the helper resets the
two associations only when that transaction began.

- *Alternative: reset each association of the site.* Rejected: a caller can hold unsaved records
  there. A record that a hook created through another association, such as
  `current_site.post_types`, stays in that association (intended).

**D4. A failed route trial rolls the switch back.** The trial raises `CamaleonCms::RouteDrawError`
inside the savepoint, so the whole switch rolls back, and `in_transaction?` of the error is true.
The themes controller now uses that value for its flash, which says that Camaleon did not save the
change. The private `rolled_back:` keyword of `AdminController#route_draw_error_message` had no
other caller, so it is gone.

The draw after the savepoint can fail too (D9), and the switch then stays. In a transaction of the
caller, `in_transaction?` of that error was true, so the flash said that Camaleon did not save the
change. A host that opens a transaction around the admin action then stored the theme with that
flash. So the helper gives that error with `in_transaction?` false. A caller that lets the error
through a transaction of its own rolls the switch back, and the error does not say so (intended).

- *Alternative: the controller compares the theme key of the site with the key of the request.*
  Rejected: the two keys are the same when an admin activates the active theme again.

This replaces the rule of the archived change
`2026-11-22-trial-route-draw`, where the theme stayed switched. That rule followed from the
missing transaction: the switch stored the theme before the hook.

**D5. Only the database rolls back.** A hook can write a file, send a mail or call another service.
The rollback does not undo that. The surveyed themes (`docs/ai/ecosystem.md`) do none of this in
`on_active` or `on_inactive`.

**D6. A hook that raises ActiveRecord::Rollback fails the switch.** The savepoint takes that error
and raises no error itself. The switch then rolled back, but the caller saw no error, and the admin
panel said that it updated the theme. So `site_install_theme` raises `ActiveRecord::ActiveRecordError`
after such a rollback. With no savepoint, the `ActiveRecord::Rollback` of the hook went to the
caller as an error.

A `before_commit` callback can raise `ActiveRecord::Rollback` at the commit of the switch, after the
route trial. Rails takes that error too. So the helper reads the state of the transaction of the
switch, and it raises the same error when that transaction did not commit.

- *Alternative: give the old theme back with no error.* Rejected: the caller cannot tell that the
  switch failed.

**D7. The helper draws the routes of the app after the savepoint.** The draw of the app routes waits for
the other requests (`CamaleonCms::RouteReloadLock`). In the savepoint, a request that waited for a
row of the switch made the draw wait for 10 seconds.

So `cama_activate_theme(key, reload: false)` draws nothing, and the savepoint ends with
`PluginRoutes.trial_routes`. That trial takes no lock, and a route file that raises still rolls the
switch back (D4). After the savepoint, `site_install_theme` gives that trial to
`PluginRoutes.request_reload`. A draw that a hook starts, for example through `plugin_install`, still
runs in the savepoint.

A commit callback can raise after the commit of the switch. The switch stays, so the helper still
draws the routes. The caller gets the error of the callback, so an error of that draw goes to the
log.

**D8. A savepoint that rolls back drops the route data that it used.** In a transaction of the
caller, the thread can already have the data of that transaction (`RouteTransactionData::Entry`). A
read in the savepoint of the switch used that data, and a miss filled it with rows of the switch. The
rollback undid the rows, but the data kept them.

So an entry notes each open savepoint that uses its data. After the rollback of such a savepoint,
the entry drops its data, and the next reads come from the database. This holds for each savepoint,
not only for a switch.

- *Alternative: give each savepoint a copy of the data.* Rejected: the data is a cache, and a read
  fills it again.

A savepoint can also get data of its own. A reload, or a request for a reload after the commit,
makes a new entry for the innermost transaction. That entry takes the place of the entry of the
caller. After the rollback of the savepoint, the thread had no entry. It then read the shared data,
which lacks the rows of the transaction of the caller. So the thread now gets an entry with empty
data for the transaction that is still open, and the next reads come from the database.

- *Alternative: put the entry of the caller back.* Rejected: each entry then needs a link to the
  entry before it, and a read fills empty data again.

A hook can open a transaction that no other transaction can join (`joinable: false`). A read there
filled the data of all threads, because only a transaction that others can join was an open
transaction for `PluginRoutes`. Such a transaction is now an open transaction too, when a transaction
that others can join is open around it.

**D9. In a transaction of the caller, the draw after the savepoint uses the data of the trial.**
Each trial loads every site with its metas and post types. So `reload` takes the trial of the
switch, and it can draw from its data with no trial of its own.

A trial reads the rows as its transaction sees them. Under REPEATABLE READ, the default of MySQL, the
transaction of the switch sees the database as it was at its first read. A row that another process
commits during the hooks is not in that view. A reload that drew from the trial after the commit left
the process without that row. Before this change, the last reload of the switch read it.

So a reload runs a trial again after the commit of the outermost transaction that was open at its
trial. A trial keeps the state of that transaction. A switch with no transaction of the caller then
runs two trials.

In a transaction of the caller, the reload draws from the trial. Under REPEATABLE READ, a new trial
reads the same view there. Under READ COMMITTED, a new trial can read a row that another connection
committed after the first trial. The reload does not read that row (intended). Each reload has such
a gap between its trial and its draw, and a second trial does not close it.

- *Alternative: a recorded limit.* Rejected: the limit leaves the process without a row that another
  process committed. The second trial costs little: about 60 to 110 ms for a switch, in probes with
  1 to 50 sites on SQLite, MySQL and PostgreSQL.
- *Alternative: a trial again only when no transaction is open at the reload.* Rejected: a later
  transaction of the same thread then draws from the old trial.
- *Alternative: a new trial only on MySQL.* Rejected: PostgreSQL with REPEATABLE READ has the same
  gap. Under READ COMMITTED, a commit between the trial and the commit of the switch has it too.
- *Alternative: READ COMMITTED for the transaction of the switch on MySQL.* Rejected: it changes the
  rows that the hooks read, and it does not help in a transaction of the caller.

Another reload can draw the routes between the two steps, and its data can be newer. The reload then
runs a trial again, as a reload without a trial does when another reload drew after its trial. A
change outside the switch can fail a trial after the switch. The theme then stays switched, and the
flash says that Camaleon kept the routes as they were.

That reload can be a reload of the switch itself. A hook that gives a post type a new slug, or
deletes one, asks for a reload after the commit. The commit callback then drew the routes from the
rows of the switch. The draw of the switch then ran a third trial and a second draw. So a reload
with a trial draws nothing when the last draw is a draw of its thread after the trial. That draw
must read its own data, with no open transaction.

In a transaction of the caller, the callback runs at the commit of the caller, after the draw of the
switch. The routes are then drawn two times (intended).

- *Alternative: count each draw of the thread.* Rejected: a draw in a transaction can read rows
  that a rollback removes. A draw from an older trial can lack rows of the newer trial.

A trial keeps the state of the transaction that was open at the trial. When that transaction rolled
back, the data of the trial can hold rows that the database does not have. So the reload then runs
a trial again.

In a request, the query cache holds the rows that the request read, and a write of another thread
does not clear it. A trial that ran again then read the rows of the first trial. So the reload drew
old data over the newer draw of the other thread, and it recorded a draw from the stored rows. So
each trial loads the route files with no query cache (`with_no_query_cache`). Before Rails 7.2,
`uncached` asks for a database connection, which can raise. The trial then runs with the cache, as
its reads rescue such an error.

The draw of the app routes reads the main site for the default host, outside the trial. All threads
share the memo of `Site.main_site`, and a request filled it from its query cache. So the read for
that memo uses no query cache. A read in a trial or in an open transaction fills no memo, and it
reads as before.

The site list of `PluginRoutes.get_sites` and the lists of the enabled plugins are data of all
threads too. The commit of another request can clear them with no reload, for example after a post
type create. A request then filled them again from its query cache, and each thread got the old
rows. So the reads for those lists use no query cache.

- *Alternative: no query cache for the second trial only.* Rejected: the first trial of a reload
  can read old rows of the request in the same way.
- *Alternative: clear the query caches of the thread.* Rejected: each later read of the request
  then queries the database again.

**D10. The switch takes the lock of the route reload first.** A draw that a hook starts runs in the
savepoint (D7), and it waited there for the other requests. On SQLite, the transaction of the switch
holds the write lock of the database. A request with a write then waited for the switch, while the
draw waited for that request. The request failed with `SQLite3::BusyException` after its busy timeout.

So `site_install_theme` takes `CamaleonCms::RouteReloadLock` exclusively before its transaction.
With no transaction of the caller, it waits for the other requests while it holds no lock of the
database. A request that starts during the switch waits until the switch is done, and the draws in
the switch do not wait.

- *Alternative: a draw in the transaction that does not wait for the requests.* Rejected: a request
  that runs during a draw finds no route helper.

A reload of another thread can hold a row that the switch waits for. An example is a post type
create: it updates the role metas of the site, and then it reloads the routes in its transaction.
That reload waited for the lock of the switch with no end, and PostgreSQL has no timeout for the row.
So a reload waits for the thread that holds the lock for `WAIT_TIMEOUT` seconds at most. Then it
draws the routes with no lock, as a reload does for a request that still runs.

- *Alternative: a lock timeout of the database in the transaction of the switch.* Rejected: it
  fails the switch, and each database needs its own statement.
- *Alternative: the lock only around the draws of the switch.* Rejected: a draw in the transaction
  then waits again for a request that waits for a lock of that transaction.

A second theme switch can ask for the lock while a switch holds it. Its request then started before
the first switch asked for the lock, or it runs outside a request. With the bound of a reload, the
second switch ran with no lock after `WAIT_TIMEOUT` seconds, and a request could start during it.
So a switch waits for the holder for `HOLDER_WAIT_TIMEOUT` seconds (30), and then it raises
`CamaleonCms::RouteReloadLock::WaitTimeout` before its first write.

- *Alternative: the switch waits with no bound.* Rejected: a caller in a transaction of its own can
  hold rows that the first switch waits for. The two then wait with no end.
- *Alternative: the switch runs with no lock, as a recorded limit.* Rejected: a draw in its
  transaction then waits again for a request that waits for a lock of that transaction.

One call can wait for the requests and for the holder. With one wait time for both, a reload that
spent its time on a request gave up at once on a holder. A switch that waited `WAIT_TIMEOUT` seconds
for the holder then waited for no request, also not for the request of the holder. So each wait has
a time of its own, and it counts only its own part of the wait. A reload then waits for 20 seconds
at most, and a second switch for 40 seconds.

- *Alternative: one wait time for both waits, as a recorded limit.* Rejected: a draw then runs while
  a request runs, and a short wait prevents that.

The lock knew its holder and each share by the thread. A fiber server runs each request in a fiber,
and those fibers can share one thread. A second switch in another fiber of the thread of the holder
then ran at once, as a nested call. A reload took the shares of the other fibers for its own, and it
did not wait for those requests.

So the lock reads `ActiveSupport::IsolatedExecutionState.isolation_level`, and it counts each fiber
when the level is `:fiber`. The examples use two fibers of one thread. No example runs a fiber
server.

- *Alternative: `ActiveSupport::IsolatedExecutionState.context`.* Rejected: Rails 7.0 does not have
  that method.
- *Alternative: the thread, as a recorded limit.* Rejected: the change is small, and Active Record
  follows the same setting.

The caller of a second switch read the site before the first switch ended. The site object holds the
options of that time, and the query cache of a request holds the theme row of that time. With those
reads, the second switch ran the `on_inactive` hook of the old theme again. It also stored the old
options over the options of the first switch. With no query cache, it raised
`ActiveRecord::RecordInvalid`.

So the switch drops the memo of the site (`cama_clear_cache`) and the query caches of the thread
after it takes the lock. It does this each time, because the other switch can also end before the
helper asks for the lock. A transaction of the caller can hold a snapshot from before the other
switch. The switch then reads the old rows again (an intended limit). On PostgreSQL under REPEATABLE
READ, its first write to a row that the other switch changed raises
`ActiveRecord::SerializationFailure`. The helper cannot read past the snapshot of the caller, so the
caller must run its transaction again.

A site object can also hold its metas in memory, for example a site of `PluginRoutes.get_sites`. The
reads of the site then come from those rows, so the switch loads them again (`metas.reload`). A load
drops a meta or a change that the caller did not save. So such metas stay as they are, and the switch
then reads the old rows (an intended limit).

- *Alternative: `current_site.reload`.* Rejected: it drops the unsaved attributes and the loaded
  associations of the caller (D3).
- *Alternative: `metas.reset`.* Rejected: each later read of the site then queries the database. After
  a switch that rolls back, the site list of all threads stays without its loaded metas.
- *Alternative: refuse the second switch when the theme changed.* Rejected: each caller of the
  helper then needs a rescue for a new error. The last switch wins, as for any two writes.
- *Alternative: record the limit.* Rejected: the lock makes the second switch start after the first
  switch each time, so the wrong hooks ran each time.

## Risks / Trade-offs

- A hook that rolls back its own work with `ActiveRecord::Rollback` in a plain `transaction` block
  now joins the savepoint of the switch. Rails then rolls back nothing for that block. Such a hook
  must open its block with `requires_new: true`. No surveyed hook does this.
- MySQL commits at once at a DDL statement, such as `create_table` in the `on_active` hook of a
  plugin. A switch that raises after that statement keeps every row that it wrote, also the rows
  after the statement. In a transaction of the caller, the savepoint is then gone. So the end of
  the switch raises an error of the database, also when no hook raises. A switch whose hook raises
  then gives that error, not the error of the hook. PostgreSQL and
  SQLite roll back DDL with the transaction.
- On PostgreSQL, a statement that fails stops the whole transaction, and each later statement
  fails. With no transaction, a hook could rescue such an error and go on. In the savepoint, the
  next statement fails the switch. The commit of a stopped transaction rolls back with no error, and
  the reads of the trial rescue their errors. So the switch reads the site before and after its
  trial, and each read fails a stopped transaction. No surveyed hook rescues an error in its body.
- The switch holds its transaction for the time of the hooks. The surveyed hooks are short. The
  other requests of the same process wait for that time (D10).
- On SQLite, the switch holds the write lock of the database until its commit. A write of another
  process waits for that time, and it fails after its busy timeout.
- Rails 8.1 permits no savepoint while the connection pool has a transaction isolation level. A
  switch in a transaction of the caller then raises `ActiveRecord::TransactionIsolationError` before
  its first write (intended). `_cama_write_field_values` asks for no savepoint there, and runs in
  the transaction of the caller. A switch that did the same stores a half switch when the caller
  rescues the error. Rails raises that error for a savepoint too, but it then drops the connection of
  the caller with its transaction. So the helper raises the error itself, before it asks for the
  savepoint (`CamaleonCms::CallerTransaction.require_savepoint!`).
- The transaction of the switch is on the connection pool of `ActiveRecord::Base`. A host that puts
  the Camaleon models on another pool gets no rollback (intended).
