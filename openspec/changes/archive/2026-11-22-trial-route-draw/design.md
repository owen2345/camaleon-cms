## Context

See `proposal.md`, "Why". The facts of the code that shape the design:

- `PluginRoutes.reload` calls `Rails.application.reload_routes!`. Rails clears each route set first
  and then loads the route files. A file that raises an error leaves the route set empty or partial.
- Camaleon has three route files: `config/routes.rb`, `config/routes/admin.rb` and
  `config/routes/frontend.rb`. Each calls `Rails.application.routes.draw`. They read the data that
  can change while the process runs. That data is the route snippets (`routes_*.txt`) of the enabled
  plugins and themes, the locales, the post types and the translations.
- A plugin gem has a route file of its own, which also calls `Rails.application.routes.draw`. It
  reads only static settings and the locales.
- `PluginRoutes` keeps the site list in `@all_sites` and the other data in `@cache`. Each thread of
  the process reads them. The specs of Camaleon and of four member plugins reset these two names, and
  `CamaleonCms::Site.@main_site`, before each example.
- The `Metas` concern already learns of a rollback with no callback. It keeps the state object of
  the open transaction and reads `rolledback?` later.
- The archived change `2026-11-22-roll-back-a-refused-site-save` moved the reload of a site to
  `after_commit` (its D5). This change keeps that decision.

## Goals / Non-Goals

**Goals:**

- A draw that fails does not break the routes of the app.
- A site save rolls back when the routes cannot be drawn, and it leaves nothing behind.
- No thread reads data of a transaction of another thread.
- After a rollback, `PluginRoutes` holds only stored data, and the routes match it.

**Non-Goals:**

- The route file of the host app, of a plugin gem and of another engine. The trial does not load
  them (D1).
- The draw that Rails starts itself: at boot, and in development after a change of a route file. It
  has no trial.
- The other server processes. Each process reloads its own routes, as before.
- The moment at which a site asks for its reload. It stays after the commit.

## Decisions

**D1. The trial loads the three route files of Camaleon into an empty route set.**
The files call `PluginRoutes.route_set.draw`. `PluginRoutes.route_set` returns the route set of the
trial of the thread, or `Rails.application.routes` when no trial runs. The trial makes an
`ActionDispatch::Routing::RouteSet`, loads the three files, and drops the route set.

- *Alternative: send `draw` of each Rails route set to a copy, and load each route file.* Rejected:
  the route file of a host app mounts engines, as the dummy app does. `mount` changes the route set
  of the mounted engine, so that trial changes objects that requests use. It also runs each host
  route file two times.
- *Alternative: put another route set in place of `Rails.application.routes`.* Rejected: the Rack
  app, the URL helper modules and Rails itself hold the first object.

**D2. The trial reads and fills data of its own.**
`@all_sites` and `@cache` stay the data that all threads share, under their names. A trial has a
data object on `Thread.current`, and each reader of `PluginRoutes` uses that object while the trial
runs. The object also keeps the text of each route snippet that the trial read.

**D3. `PluginRoutes.reload` runs the trial, then makes its data the cached data, then draws.**
The trial runs before the reload takes its lock, so requests do not wait for it. `PluginRoutes`
counts its reloads. When the count changed between the trial and the lock, the reload runs the trial
again in the lock.

The real draw then reads the data and the snippet text of the trial. At the end of the reload,
`PluginRoutes` drops the snippet text, so a later draw by Rails reads the files again.

- *Alternative: run the trial in the lock each time.* Not chosen: each request then waits for two
  draws.

**D4. `PluginRoutes.check_routes` runs the trial alone, and a site calls it in its transaction.**
`Site` calls it in `after_update` for a new slug, and in a `before_destroy` that runs first. The
delete removes the media folder of the site, and a rollback does not bring that folder back. An
error of the trial goes through the transaction, which rolls back.

The check drops its data. That data is not committed, and the transaction can still roll back after
the check, as a refused site settings save does.

- *Alternative: keep the data of the check, and draw from it after the commit.* Not chosen: the
  check then must run after the last write of the transaction. Rails has no public callback for
  that moment.

**D5. `CamaleonCms::Site.main_site` keeps its memo, and Camaleon clears it.**
`PluginRoutes` clears the memo when it replaces or clears the shared data. `Site` clears it after
each commit of a site. `main_site` does not fill the memo while a trial runs or a transaction is
open. The site with the lowest id is also the first site of `PluginRoutes.get_sites`, which is in
the order of the id.

A host app can redefine `main_site` with the same memo: camaleon_website does it for the site with
the id 132. The clear of the memo makes that method read its site again too.

The routes hold the slug of the main site as their default host. A draw in a transaction can read
the old slug: from the memo, or before the save of the new slug. So `PluginRoutes` records the
default host of each reload. The main site asks for the reload after its commit when that host is
not its stored slug.

- *Alternative: `main_site` does not read its memo in a transaction.* Not chosen: a draw before
  the save of the new slug still reads the old slug, and each read in a transaction costs a query.

- *Alternative: return the first site of `PluginRoutes.get_sites`.* Not chosen: that object carries
  loaded metas and post types, and plugins can call `main_site`. The memo stays the smaller change.

**D6. Data that `PluginRoutes` reads in a transaction stays on the thread.**
A transaction is open when the connection of the thread has a transaction that other transactions
can join. The transaction of the test fixtures is not such a transaction, so a spec behaves as
production does.

- A read of data that is not in the shared data, in an open transaction, makes the data object of
  the thread. It starts as a copy of the shared data.
- A clear of the cached data in an open transaction makes an empty data object of the thread. The
  reload and the reload request clear the data.
- The data object keeps the state object of its transaction. It also keeps the state object of
  the outermost such transaction of the connection. A `requires_new` transaction is a savepoint,
  and only the commit of the outermost transaction stores its changes. The transaction rolled back
  when one of the two states says `rolledback?`. A commit that loses the connection leaves the
  state as `invalidated?`, from Rails 7.1. The database can then hold the change or not, so that
  state counts as rolled back.
- The transaction committed when the outer state says `fully_committed?`. It also committed when
  that state says `committed?` and the connection has no open transaction as defined above. Rails
  takes a transaction from its stack before it sends COMMIT. In that window, the state of a
  savepoint says `committed?`, and the connection has no open transaction.
- Rails has no public reader for the outermost transaction. The data object reads the stack of
  the transaction manager. With no such stack, it reads only the state of its own transaction.
- After the commit, `PluginRoutes` drops the data object. It clears the shared data when the data
  object came from a clear.
- After the rollback, `PluginRoutes` drops the data object. It reloads the routes when a draw of the
  app route set used the data object.
- The thread settles its data object at its next read of `PluginRoutes` data. `PluginRoutes` also
  keeps a list of the data objects that need a step after their transaction. Each thread settles the
  entries of that list whose transaction is over. A data object whose thread is dead counts as
  rolled back.
- `Site` and `PostType` call the settle step in `after_commit` and `after_rollback`, so the step
  runs right after the transaction.

- *Alternative: `ActiveRecord::Base.current_transaction.after_commit`.* Rejected: Rails has it from
  7.2, and CI runs Rails 7.1.
- *Alternative: only the callbacks of `Site` and `PostType`.* Rejected: a reload that plugin code
  calls in its own transaction has no record with a callback.

**D7. `PluginRoutes.reload_after_commit` keeps a reload request on the data object of the thread.**
With an open transaction, it makes an empty data object (D6) and marks it. The settle step calls
`PluginRoutes.request_reload` after the commit, and it drops the mark after a rollback. With no
open transaction, the method calls `PluginRoutes.request_reload` at once.

**D8. A post type calls `PluginRoutes.request_reload` in its transaction only for a create.**
The create adds a helper name, `cama_post_type_<id>_path`, that a hook later in the transaction can
call. A new slug and a delete add no helper name. `PostType` calls
`PluginRoutes.reload_after_commit` for them, in `after_update` and `after_destroy`. Those callbacks
run on the instance that saved the change, so no stored value is read after the commit.

**D9. A reload after a rollback does not raise.**
When the reload of D6 fails, `PluginRoutes` logs the error and goes on. An error there hides the
error that caused the rollback. A read of `PluginRoutes` data that settles a commit logs the error
of the reload of D7 too: the read must give its data.

**D10. A trial that fails raises `CamaleonCms::RouteDrawError`, and the admin answers it.**
The error of a route file can be a `SyntaxError`, which is not a `StandardError`. The trial puts
it in a `CamaleonCms::RouteDrawError`, a `StandardError`. The message is the class and the first
line of the message of the route file error, and `cause` is that error. The new error also
records whether a transaction was open on the thread (D6) when the trial failed.

`AdminController` has a `rescue_from` for the error. It calls `refuse_admin_save`, as the
handlers of the other refusals do, and it raises the error again for a GET or HEAD request. It
logs the error with its backtrace. The admin shows a flash as HTML, so the handler escapes the text
of the route file error for the flash.

The theme switch is a GET request, so `ThemesController` rescues the error itself. It redirects to
the list of the themes with the flash, and that list draws no routes. Its message is always the
message for no open transaction. The switch stores the theme before the `on_active` hook, so the
theme stays switched when a save of that hook rolls back.

`config/locales/camaleon_cms/admin/en.yml` gets two messages:

- A transaction was open: Camaleon did not save the change. The raise goes through that
  transaction, which rolls back.
- No transaction was open: Camaleon kept the routes as they were. The change of the request can
  be stored, as after a save of the languages or a post type with a new slug.

- *Alternative: a server error, as on master.* Rejected by the user: the admin must get a clear
  message.
- *Alternative: a validation error of the site.* Not chosen: it covers only the site. A plugin
  activation, a theme switch, a post type and a save of the languages reload the routes too.

## Risks / Trade-offs

- [Each reload loads the route files of Camaleon two times] → The trial runs outside the lock, so
  only the request that reloads waits longer. In the dummy app, with one site and 228 routes, a
  reload took 63 ms before the change and 94 ms after it. A trial alone took 37 ms.
- [A snippet route name clashes with a host route] → The trial does not see the clash. The real
  draw then fails as before. The route files of the host app and of the gems do not change while
  the process runs.
- [A snippet that mounts an engine changes the route set of that engine] → No bundled plugin or
  theme mounts an engine. The upgrade notes name the limit.
- [The design reads `current_transaction`, `joinable?` and the transaction state of Rails] → The
  `Metas` concern reads the same state. The specs of this change run on each Rails version of CI.
- [The design reads `@stack` of the transaction manager, which is private] → Rails 6.1 to 8.1 have
  it. Without it, a savepoint is settled as before, and its spec fails on that Rails version.
- [A request reaches the route of an uncommitted post type] → It gets the 404 page, as with no
  such route.
- [**BREAKING**: code needs the route of a new slug in its transaction] → The upgrade notes tell
  it to call `PluginRoutes.reload`.
- [The check passes, and the trial after the commit fails] → The save is stored, and the old
  routes stay. The reload raises the error.
- [The message shows the text of a route file error] → Only a signed-in role of the admin area
  gets it. The log has the backtrace.
- [A savepoint rolls back, and its transaction goes on] → A read in it can leave data with the
  thread until that transaction is over. A reload in the savepoint has data of its own, and its
  rollback draws the routes again.
- [A value of `PluginRoutes.cache_variable` that code writes in a transaction is gone after the
  commit] → The next read computes it again.

## Open Questions

None that change the specs or the tasks.
