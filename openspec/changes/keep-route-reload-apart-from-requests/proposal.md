# Keep a reload of the routes apart from the requests

## Why

`PluginRoutes.reload` clears the route set of the app and draws it again. Camaleon calls it in a
request: the save of a post type or a site, a plugin or theme change, the languages of a site. On a
server with more than one thread, a request that runs during the draw finds no route helpers. It
raises a `NameError` for `cama_root_url` or an `ActionController::UrlGenerationError`.

The CI of PR #1347 showed it. With Chrome 157, a spec sent a GET while the POST that created a post
type still ran. One job got the `NameError`. In another job, each later `url_for` of the run raised
`UrlGenerationError` (36 failures).

## What Changes

- A new middleware, `CamaleonCms::RouteReloadLock`, gives each request a share of a lock until the
  app returns its response.
- `PluginRoutes.reload` takes the lock exclusively. It waits until the other requests are done, and
  new requests wait until the draw is done.
- The reload waits for 10 seconds at most. Then it draws the routes while the requests run, as
  Camaleon did before, and it logs a warning.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `multisite-route-draw-readiness`: a reload of the routes does not run while a request runs.

## Impact

- `lib/camaleon_cms/route_reload_lock.rb`, `lib/camaleon_cms.rb`, `lib/camaleon_cms/engine.rb`
- `lib/plugin_routes.rb`
- `spec/lib/camaleon_cms/route_reload_lock_spec.rb`
