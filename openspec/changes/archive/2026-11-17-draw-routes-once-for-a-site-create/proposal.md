# Draw the routes less often for a site create

## Why

An admin creates a site with `POST /admin/settings/sites`. That request calls `PluginRoutes.reload`
8 times. The default post types cause 2 calls, the site 1, the default plugins 4 and the theme 1.
Each call clears the route set of the app and draws it again. Each call also waits until the other
requests are done (`CamaleonCms::RouteReloadLock`). The delete of a site draws the routes 3 times.

The CI of PRs #1345 and #1348 showed the cost. On a slow runner, the create was longer than the 2
seconds that `spec/features/admin/sites_spec.rb` waited for the success message.

Five of the 8 draws add no route. A site has no route of its own. A plugin or a theme that another
site already has is in the route set already.

## What Changes

- New `PluginRoutes.reload_once`. It runs a block. At the end of the block, it draws the routes one
  time when code in the block left a draw to it and the block drew no routes after that.
- New `PluginRoutes.request_reload`. Outside such a block, it reloads the routes at once, as
  `PluginRoutes.reload` does. In the block, it clears the caches of `PluginRoutes` at once. It leaves
  the draw to the end of the block only when the draw adds no route.
- `PluginRoutes.reload` does not change. It draws the routes at once, also in the block.
- The save and the delete of a post type or a site, `plugin_install` and `site_install_theme` call
  `PluginRoutes.request_reload`.
- The create and the delete of a site in the admin panel run in `PluginRoutes.reload_once`, and
  `site_after_install` does too. A site create then draws the routes 3 times, when another site
  already has the default plugins and the theme. A site delete draws them one time.
- `create_site` of `spec/features/admin/sites_spec.rb` waits 10 seconds for the success message.

A route helper exists at the same moment as before, for each hook and each model callback of a
plugin.

**Not in this change:** the plugin switch of the admin panel, which draws the routes 2 times. The
installer of the first site is not in it either: each of its draws adds a route.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `multisite-route-draw-readiness`: in a block of code, a draw that adds no route waits for the end
  of the block. The create and the delete of a site use it.

## Impact

- `lib/camaleon_cms/route_reload.rb` (new): `reload`, `reload_once`, `request_reload`. `PluginRoutes`
  extends it.
- `app/models/camaleon_cms/post_type.rb`, `app/models/camaleon_cms/site.rb`
- `app/helpers/camaleon_cms/plugins_helper.rb`, `app/helpers/camaleon_cms/site_helper.rb`
- `app/controllers/camaleon_cms/admin/settings/sites_controller.rb`
- `spec/lib/plugin_routes_reload_once_spec.rb` and `spec/requests/admin/settings/sites_controller_spec.rb`
  (new), `spec/features/admin/sites_spec.rb`
- `docs/upgrading-to-2.9.5.md`, `CHANGELOG.md`
- Plugins and themes: `PluginRoutes.reload` keeps its contract. A callback of
  `PluginRoutes.add_after_reload_routes` runs after each draw, so it runs less often.
