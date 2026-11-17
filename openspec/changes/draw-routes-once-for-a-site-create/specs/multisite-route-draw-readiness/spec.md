## ADDED Requirements

### Requirement: A draw that adds no route waits for the end of a block

`PluginRoutes.reload_once` SHALL run its block. In the block, `PluginRoutes.request_reload` SHALL
clear the caches of `PluginRoutes` at once. It SHALL leave the draw to the end of the block only when
the draw adds no route to the routes of the last reload. At the end of the block,
`PluginRoutes.reload_once` SHALL draw the routes one time when a call left a draw to it. It SHALL
draw them also when the block raises an error.

A draw adds a route when the last reload did not have one of these:

- a post type with its present slug
- the route files of a plugin or a theme that a site has enabled
- the present set of site languages

A call before the first reload of the process SHALL draw at once.

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

#### Scenario: A block that asks for no draw

- **WHEN** no code in a `PluginRoutes.reload_once` block calls `PluginRoutes.request_reload`
- **THEN** the routes are not drawn

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
plugins and that theme. The last draw SHALL be done before the admin gets the response. The delete of a site in the
admin panel SHALL draw the routes one time. `site_after_install` SHALL draw the routes one time for
its plugins and its theme, under the same condition as the create.

#### Scenario: An admin creates a second site

- **WHEN** an admin creates a site, and another site already has each default plugin and the theme
- **THEN** the routes are drawn 3 times, and they then have the route of each post type of the new
  site

#### Scenario: An admin deletes a site

- **WHEN** an admin deletes a site
- **THEN** the routes are drawn one time, and they then have no route of a post type of that site

#### Scenario: A create that fails

- **WHEN** an admin sends a site that is not valid
- **THEN** the routes are not drawn, and the admin sees the form again
