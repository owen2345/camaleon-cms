# Design

## Context

See `proposal.md`, "Why". These facts of the code shape the design:

- Three parts of the route set come from the database. `config/routes/frontend.rb` draws one
  `cama_post_type_<id>` route for each post type of each site. `PluginRoutes.load` gives the route
  files of each plugin and each theme that a site has enabled. The `locale` scope of the frontend
  routes has the languages of all sites (`PluginRoutes.all_locales`). No other route depends on a
  site.
- `PluginRoutes.reload` does two things. It clears the caches of `PluginRoutes` (the list of the
  sites and the `cache_variable` values), and it draws the routes.
- `plugin_install` reloads the routes and then runs the `on_active` and `plugin_after_install` hooks
  of the plugin. `PostTypeDecorator#the_url` calls `PluginRoutes.reload` when the route helper of its
  post type does not exist.
- No surveyed plugin, theme or host app calls `PluginRoutes.reload` or a `cama_post_type_<id>`
  helper itself. Three themes call `plugin_install` in their `on_active` hook (`cama-ecommerce-theme`,
  `camaleon-cms-efashion`, `e_shop` of `camaleon_website`).

## Goals / Non-Goals

**Goals:**

- The create and the delete of a site draw the routes less often.
- A route helper exists at the same moment as before, for each hook and each model callback of a
  plugin.
- Code outside a `PluginRoutes.reload_once` block gets the same draws as before. The delete of a site
  is the one exception (D9).

**Non-Goals:**

- The plugin switch of the admin panel. `plugin_install` and `PluginsController#toggle` each reload.
- The installer of the first site. Each of its draws adds a route.
- One draw for the two default post types of a new site (D2).

## Decisions

**D1. `PluginRoutes.reload` stays a draw at once. The new `PluginRoutes.request_reload` is the call
that can wait.** Only the callers that Camaleon owns change to `request_reload`. A plugin that calls
`PluginRoutes.reload` and then uses a route gets the route, in a block too.

- *Alternative: `PluginRoutes.reload` waits in the block.* Rejected: a hook that runs in the block
  and uses a route after its own reload gets a `NoMethodError`. This repo cannot check each plugin.

**D2. A draw waits only when it adds no route (the user's choice, 2026-11-17).**
`PluginRoutes.reload` records what its draw read: the post types with their slugs, the keys of the
enabled plugins and themes, and the languages. In a block, `request_reload` reads the same data again
and compares. A new post type, a new slug, a new plugin or theme key, or a new language draws at
once. A site create then draws 3 times: for the Post type, for the Page type, and at the end.

- *Alternative: one draw at the end of the block for all calls.* Rejected: plugin code that runs
  in the block can call the `cama_post_type_<id>` helper of a new post type. It gets a
  `NoMethodError`.
- *Alternative: a draw before each hook handler, and only then.* Rejected: it gives 2 draws, but a
  model callback that a plugin adds with `class_eval` is not a hook.
- *Alternative: a rule in each caller, for example `drawn_plugin?` in `plugin_install`.* Rejected:
  the same question has one answer in `request_reload`, for each present and future caller.

**D3. `request_reload` clears the caches at once, also when the draw waits.** The code after it reads
the lists that `PluginRoutes` caches, for example the enabled plugins of the site for the hooks. The
comparison of D2 fills the caches again from the database.

**D4. Before the first reload of the process, `request_reload` draws at once.** The draw at boot
does not go through `PluginRoutes.reload`, so the record of D2 is empty until the first reload. A
draw that raises an error empties the record too, because the route set is then not whole.

**D5. The state of the block is local to the thread.** One `Thread.current` key holds the flag for
the draw. A request on another thread reloads at once. A block in a block uses the state of the outer
block, and the outer block draws.

**D6. The draw at the end runs in `ensure`.** Before, each reload ran before a later error. When the
block and the draw both raise, the caller gets the error of the draw.

**D7. A delete can wait.** A post type or a site that the block deletes adds no route. Its route
stays until the end of the block. A request for it during that time finds no post type, as a request
did between the delete and the reload before. A language that the block removes waits in the same
way (the user's choice, 2026-11-17). The `locale` scope accepts that language until the end of the
block. The delete of a site with a language of its own is such a case.

**D8. Three callers open a block.** `SitesController#create` puts the save and `site_after_install`
in one block, and `SitesController#destroy` the delete. `site_after_install` opens its own block, for
the installer, the site factories of the plugins and the host apps that call it.

**D9. A post type that its site destroys asks for no draw (the user's choice, 2026-11-17).** The
delete of a site removes the metas of the site before its post types. The site then reads the default
theme and the default language. A call at that moment draws at once when no site had them at the last
reload.

So only the site asks for a draw, after its own delete. A site delete then draws one time, in a block
or not. Outside a block, it drew one time for each post type and one more time before. That is 3
times for a site with the 2 default post types.

- *Alternative: keep the code, and name the second draw in the requirement and the notes.* Rejected:
  the code can remove the cause of that draw.
- *Alternative: a post type asks for no draw only in a block.* Rejected: the model then knows about
  the block, and a site delete outside a block keeps 3 draws.

**D10. A draw at once reads the data of the routes two times (the user's choice, 2026-11-17).**
`request_reload` reads the data for the comparison of D2. `PluginRoutes.reload` then clears the caches
and reads the data again for the draw. `reload` first waits for the other requests, and another
thread can reload the routes in that time. That reload fills the caches from its own database
connection, so they lack a post type that this thread did not commit yet.

- *Alternative: the draw uses the caches of the comparison.* Rejected: after a reload on another
  thread, the draw has no route for the new post type.
- *Alternative: the draw skips the clear when no other clear came after the comparison.* Rejected: it
  saves a few queries before a draw, and it adds state to the code that holds the locks.

## Risks / Trade-offs

- [A callback of `PluginRoutes.add_after_reload_routes` runs less often] → It ran 8 times for a site
  create, and it now runs 3 times. It ran 3 times for a site delete, and it now runs one time, outside
  a block too. Such a callback runs after a draw, and each draw still runs it.
- [A plugin route file that reads data outside the record of D2] → Its route comes at the end of
  the block. No bundled or surveyed plugin has such a route file.
- [Each `request_reload` in a block reads the data of the routes again] → It is a few queries. A
  draw that waits reads the same data one time, at the end of the block. A draw at once reads it a
  second time (D10).
