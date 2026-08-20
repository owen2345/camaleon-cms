# ecosystem-plugin-bindings

## ADDED Requirements

### Requirement: Hook handlers execute with the request controller as receiver
`hooks_run` SHALL dispatch each handler on the object handling the current request, so that handlers
can read and write controller state: `params`, `flash`, `session`, `response`, `redirect_to`,
`render_to_string`, URL helpers, authorization helpers, and instance variables set earlier in the
same request. A handler SHALL be able to set an instance variable in one hook and read it in another
hook of the same request.

Consumers: `camaleon_post_created_at` reads `@post` in `new_post`/`edit_post`; `camaleon_lazy_loader`
writes `response.body` and shares `@skip_lazy_loader` across hooks; `camaleon_admin_ajax`,
`camaleon-spree`, `camaleon-download`, `cama_subscriber` and `camaleon_export_import` write `flash`
or read `params` from `admin_before_load`/`app_before_load`.

#### Scenario: A hook handler reads a controller instance variable
- **WHEN** a plugin registers an `edit_post` handler that reads `@post`
- **THEN** the handler SHALL receive the post assigned by the posts controller for that request

#### Scenario: A hook handler writes flash and asset state
- **WHEN** a plugin registers an `admin_before_load` handler that sets `flash[:error]` and calls
  `append_asset_libraries`
- **THEN** the flash message SHALL render on that request and the registered assets SHALL be emitted
  in that request's layout

#### Scenario: State set in one hook is visible in another
- **WHEN** a plugin sets an instance variable in an `on_render_sitemap` handler and reads it in a
  `front_after_load` handler of the same request
- **THEN** the value SHALL be the one written earlier in that request

### Requirement: Hook payloads are mutated in place
Where the engine passes a Hash to `hooks_run` and reads values back from it, the engine SHALL seed
every key it will read, SHALL pass the same object to every handler, and SHALL read back the mutated
object. Seeded collection values SHALL be non-nil and unfrozen so handlers can use `<<`, `+=` and
`[]=` without a nil guard. `hooks_run` SHALL pass exactly one payload argument.

Consumers: `camaleon_sitemap_customizer` accumulates into all four sitemap skip lists and overrides
`args[:render]`; `cama_external_menu` suppresses a menu item with `args[:parsed_menu] = false`;
`camaleon-spree` writes `args[:layout]` and `args[:custom_menus]`; `camaleon_post_created_at` and
`camaleon-post-clone` append to `args[:extra_settings]`; `camaleon_lazy_loader` binds
`on_render_sitemap` with a handler that ignores its argument.

#### Scenario: A handler accumulates into a seeded collection
- **WHEN** an `on_render_sitemap` handler appends ids to `args[:skip_post_ids]` and
  `args[:skip_cat_ids]`
- **THEN** the rendered sitemap SHALL omit exactly those records

#### Scenario: A handler replaces a scalar the engine reads back
- **WHEN** an `on_render_sitemap` handler assigns a different template name to `args[:render]`
- **THEN** the engine SHALL render that template, and `args[:layout]` SHALL remain independently
  overridable

#### Scenario: A handler declares fewer parameters than the payload
- **WHEN** a registered handler accepts one argument and ignores it
- **THEN** the hook SHALL run without an argument-count error

### Requirement: Admin menus are registrable through four entry points
The engine SHALL accept admin menu registration through `admin_menu_append_menu_item`,
`admin_menu_insert_menu_before`, `admin_menu_insert_menu_after`, and `admin_menu_add_menu`, callable
from an `admin_before_load` handler. A menu entry SHALL accept `icon`, `title`, `url`, a nested
`items` array of the same shape, and a `datas` value supplied as a pre-rendered attribute string.

A menu `title` SHALL be permitted to contain inline presentational markup. The engine SHALL NOT
render such a title as visible escaped text.

Consumers: `cama_contact_form` uses `admin_menu_append_menu_item` with a `datas` string containing
single-quoted `data-intro` and `data-position` attributes; `cama_subscriber` and `camaleon-download`
use the insert forms with nested `items`; `camaleon-ecommerce` supplies a title containing `span`
and `small` elements carrying a live order count.

#### Scenario: A plugin registers a menu with nested items
- **WHEN** a plugin calls `admin_menu_insert_menu_after` from `admin_before_load` with an entry
  carrying an `items` array
- **THEN** the parent entry and each child SHALL render in the admin sidebar

#### Scenario: A menu title carries inline markup
- **WHEN** a registered menu title contains `<span>` and `<small>` elements
- **THEN** those elements SHALL render as markup rather than as literal text

#### Scenario: A menu carries a pre-rendered datas string
- **WHEN** a registered entry supplies `datas` as a string of single-quoted `data-*` attributes whose
  values contain double quotes
- **THEN** each attribute SHALL render with its value intact

### Requirement: Plugin and theme asset helpers accept their published arities
`plugin_asset_path` SHALL accept both a single asset name and an asset name with an explicit plugin
key. `plugin_view` SHALL accept both a single view path and a view path with an explicit plugin key.
`plugin_asset`, `plugin_gem_asset`, `append_asset_libraries` and `cama_load_custom_assets` SHALL
remain available to plugin code, with `append_asset_libraries` accepting a nested hash of library
name to `js`/`css` arrays.

Consumers: `camaleon-cms-language-editor` calls `plugin_asset_path` with one argument and
`camaleon_admin_ajax` with two; `cama_meta_tag` calls `plugin_view` with both arities; `cama_subscriber`,
`cama_image_lightbox`, `camaleon-post-order-plugin` and `cama_tinymce_template` register assets
through the library helpers.

#### Scenario: An asset helper is called with an explicit plugin key
- **WHEN** a plugin calls `plugin_asset_path('admin', 'camaleon_admin_ajax')`
- **THEN** the helper SHALL resolve the asset for the named plugin

#### Scenario: An asset helper is called without a plugin key
- **WHEN** a plugin calls `plugin_asset_path('admin')` from its own helper
- **THEN** the helper SHALL resolve the asset against the calling plugin

### Requirement: PluginRoutes exposes a stable read surface at route-draw time
`PluginRoutes.system_info`, `PluginRoutes.static_system_info`, `PluginRoutes.all_locales`,
`PluginRoutes.migration_class` and `PluginRoutes.db_installed?` SHALL be callable while the host
application draws routes and while plugin migrations load. `all_locales` SHALL return a value that
interpolates into a route-constraint regular expression. `static_system_info['user_model']` SHALL
remain readable, defaulting to `CamaleonCms::User`.

The `PluginRoutes` constant SHALL tolerate being defined by the host application before the engine
loads.

Consumers: `cama_subscriber`, `cama_image_lightbox`, `cama-stripe-donation`, `camaleon_cms_rating`
and `camaleon-download` interpolate `all_locales` into a `scope '(:locale)'` constraint;
`camaleon_cms_rating` resolves `user_model` at class-definition time; `camaleon_oauth` reads
`db_prefix` in migrations; both surveyed host applications define `PluginRoutes` in their own
`lib/plugin_routes.rb` before bundling the gem.

#### Scenario: A plugin constrains routes by locale
- **WHEN** a plugin's `config/routes.rb` interpolates `PluginRoutes.all_locales` into a scope
  constraint
- **THEN** the application SHALL boot and the locale-scoped routes SHALL recognise each configured
  locale

#### Scenario: The host application predefines the constant
- **WHEN** the host application requires its own file defining `PluginRoutes` from its `Gemfile`
- **THEN** loading the engine SHALL NOT raise a constant conflict

### Requirement: Uploader entry points keep their option and return contract
`upload_file` and `cama_tmp_upload` SHALL accept an options hash carrying at least `maximum`, `path`,
`folder`, `dimension`, `formats`, `name` and `remove_source`, and SHALL remain callable with no
options. The returned value SHALL expose `file_path`, `url` and `error` under indifferent access.

A `before_upload` handler SHALL be permitted to replace `settings[:uploaded_io]`, provided the
replacement reports the same `path`. The engine SHALL compute the stored filename before running the
handler.

Consumers: `cama_contact_form` passes `maximum`, `path` and `name` from an unauthenticated endpoint;
`camaleon_export_import` calls `cama_tmp_upload` with no options and reads `file_path`;
`camaleon_website`'s store plugin reads both `res['url']` and `res[:error]` from the same result;
`camaleon_image_optimizer` rewrites the file in place and rebinds `settings[:uploaded_io]`.

#### Scenario: A caller reads the result with either key type
- **WHEN** a plugin reads `result['url']` and `result[:error]` from an `upload_file` result
- **THEN** both SHALL resolve

#### Scenario: A before_upload handler replaces the IO object
- **WHEN** a handler optimises the file in place and assigns a new `File` to `settings[:uploaded_io]`
- **THEN** the stored file SHALL keep the filename derived before the handler ran

### Requirement: Mail helpers pass plugin-defined options through
`cama_send_email` and `cama_send_mail_to_admin` SHALL accept an options hash and SHALL NOT reject
keys they do not recognise. `cc_to` SHALL accept an array as well as a string.

Consumers: `cama_contact_form` passes `attachments` and `extra_data`; `camaleon-ecommerce` passes
`files`, `template_name` and a plugin-specific `ecommerce_invoice`; `cama_subscriber` passes `from`,
`template`, `layout_name` and an array `cc_to`; `camaleon_website`'s store plugin passes `attachs`
and a string `cc_to`.

#### Scenario: A caller supplies an unrecognised option key
- **WHEN** a plugin calls `cama_send_email` with an option key the engine does not read
- **THEN** the mail SHALL be sent and the key SHALL be available to `email_late` handlers

#### Scenario: A caller supplies multiple carbon-copy recipients
- **WHEN** `cc_to` is an array of addresses
- **THEN** each address SHALL receive the message

### Requirement: Session and site helpers remain overridable by module reopening
`CamaleonCms::SessionHelper` and `CamaleonCms::SiteHelper` SHALL define their public helpers —
including `cama_current_user`, the admin login, register and logout path helpers, and `current_site`
— as ordinary instance methods on the module, so that a host application or plugin can replace one by
reopening the module. `login_user_with_password` SHALL return the authenticated user without
redirecting or writing a session cookie as a side effect. `cama_current_user` SHALL continue to
resolve an API identity from an OAuth access token when one is present.

Consumers: `camaleon-spree` reopens `CamaleonCms::SessionHelper` to delegate `cama_current_user` and
the three path helpers to Spree; `camaleon_oauth` includes `SessionHelper`, `SiteHelper` and
`HooksHelper` into `Object` and calls `login_user_with_password` from a Doorkeeper credentials block.

#### Scenario: A plugin replaces the current-user resolver
- **WHEN** a plugin reopens `CamaleonCms::SessionHelper` in a `to_prepare` block and redefines
  `cama_current_user`
- **THEN** engine controllers SHALL call the redefined method

#### Scenario: An API client authenticates by access token
- **WHEN** a request carries a valid OAuth access token and no session cookie
- **THEN** `cama_current_user` SHALL resolve the token's resource owner

### Requirement: Removed or renamed public APIs are recorded against their consumers
Where an engine change removes, renames or narrows a public helper, model method or constant that
`docs/ai/ecosystem.md` records as bound, the change SHALL state the affected consumer and the chosen
disposition — restore, alias, or document as withdrawn — in its proposal.

#### Scenario: A change removes a bound API
- **WHEN** a proposal removes a method that the ecosystem inventory records as bound
- **THEN** the proposal SHALL name the consuming repository and state the disposition

#### Scenario: A change removes an unbound API
- **WHEN** a proposal removes a method with no recorded consumer
- **THEN** the inventory SHALL be cited as the basis and no compatibility shim is required
