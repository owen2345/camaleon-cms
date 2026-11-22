## Why

`PluginRoutes.reload` clears the route set of the app and then loads the route files. A route file
can raise an error, for example the route file of a plugin with a syntax error. The app then keeps
an empty or partial route set, and each request fails until the next good draw.

A site now asks for its reload after the commit, so a draw that fails no longer rolls the site save
back. The save is stored, and the routes are broken.

`PluginRoutes` also keeps data that it reads in a transaction. A post type draws the routes in its
transaction, and the cached site list then holds data that is not committed. Other requests read
that data, and a rollback leaves it in the list.

`CamaleonCms::Site.main_site` keeps one site object for the life of the process. After a new slug of
the main site, it returns the old slug until the process starts again. The routes hold that slug as
their default host, so they keep the old slug too.

## What Changes

- `PluginRoutes.reload` draws the routes on trial first. The trial loads the route files of Camaleon
  into an empty route set that only the thread uses. A trial that raises an error leaves the routes
  and the cached data as they were, and the reload raises that error.
- The real draw reads the data that the trial read. From the database, it reads at most the main
  site.
- A trial that fails raises the new `CamaleonCms::RouteDrawError`. Its message names the error of
  the route file.
- An admin request answers that error as a refused save. The answer is a redirect back with a
  message, or the message as text with a 422 for an XHR. Before, a draw that failed gave a server
  error.
- The theme switch of the admin is a GET request. It answers that error with a redirect to the list
  of the themes and a message.
- The new `PluginRoutes.check_routes` runs the trial alone.
- A site runs that check in its transaction, for a new slug and for a delete. A draw that cannot
  work rolls the save back, and nothing else changes.
- `CamaleonCms::Site.main_site` reads the main site again after a reload and after the commit of a
  site. A read in a transaction or in a trial does not fill it.
- The routes get the new slug of the main site as their default host. The main site asks for the
  reload after its commit when the last reload drew another default host.
- Data that `PluginRoutes` reads while a transaction is open stays with the thread of that
  transaction. Other threads read the committed data. A rollback drops the data of the thread, and
  it draws the routes again when a draw used that data.
- A `requires_new` transaction is a savepoint. Its data counts as committed only after the commit of
  the outermost transaction. A commit that loses the connection counts as a rollback.
- The new `PluginRoutes.reload_after_commit` asks for a reload that waits for the commit of the open
  transaction. A rollback drops the request.
- **BREAKING**: a post type draws the routes in its transaction only when it is created. For a new
  slug and for a delete, it asks with `PluginRoutes.reload_after_commit`. Code in the same
  transaction no longer finds the route of the new slug before the commit.
- `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md` tell an upgrader what changes.
- `docs/ai/reference.md`, `docs/ai/testing.md` and `docs/ai/ecosystem.md` record the rules for the
  code and its specs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `multisite-route-draw-readiness`: new requirements for the trial draw, the admin answer, the site
  check, the main site and the data of a transaction. It also gets requirements for the reload after
  the commit and for the post type. The requirement on the reload of a site after its commit loses
  its exception for data that the transaction loaded. It gets the rule of the default host for the
  main site.

## Impact

- `lib/camaleon_cms/route_reload.rb`, `lib/plugin_routes.rb` and new modules beside them: the trial,
  the data of a thread and the reload after the commit.
- `config/routes.rb`, `config/routes/admin.rb`, `config/routes/frontend.rb`: they draw into
  `PluginRoutes.route_set`.
- `app/models/camaleon_cms/site.rb`: the check in the transaction, `main_site`, and the reload for
  the default host.
- `app/controllers/camaleon_cms/admin_controller.rb` and `config/locales/camaleon_cms/admin/en.yml`:
  the answer to `CamaleonCms::RouteDrawError`, with its two messages.
- `app/controllers/camaleon_cms/admin/appearances/themes_controller.rb`: the answer of the theme
  switch.
- `app/models/camaleon_cms/post_type.rb`: the moment at which a post type asks for the draw.
- Specs: new examples for each requirement, and changes to the examples that set the cached data of
  `PluginRoutes` directly.
- Cost: each reload loads the route files of Camaleon two times.
- Ecosystem: `PluginRoutes.reload`, `request_reload`, `reload_once`, `get_sites` and
  `cache_variable` keep their signatures. The specs of four member plugins reset
  `PluginRoutes.@all_sites`, `PluginRoutes.@cache` and `Site.@main_site`, so those names stay. A
  plugin that changes the slug of a post type in a transaction, and then needs its route there, must
  call `PluginRoutes.reload` itself.
