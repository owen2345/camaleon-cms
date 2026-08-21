# Ecosystem Inventory

What external plugins, themes and host applications bind to in this engine. The contracts these
bindings imply are specified in `openspec/specs/ecosystem-plugin-bindings/spec.md`; this file is the
evidence behind them.

**Surveyed 2026-08-05** against master `73141b88`: the sixteen plugins and four themes listed in
`README.md` that have public repositories, plus two production host applications. Read-only survey —
grep, file reads and `git log`, no execution of ecosystem code.

**Staleness is the point.** Most of these repositories have not been touched in years and will not
be updated to accommodate a breaking change. Two are unloadable as published. Treat the table as the
*visible* surface: `AGENTS.md` notes that more consumers exist than this repo can enumerate.

## How to use this

Before removing, renaming or hardening a public API, search this file for it. Three outcomes:

- **No consumer listed** — proceed on the engine's merits, cite this file in the proposal.
- **A consumer listed** — name it and the disposition in the proposal (spec requirement
  "Removed or renamed public APIs are recorded against their consumers").
- **Hardening rather than removal** — check the "hardening hazards" section below first. The survey's
  clearest lesson is that removals are cheap here and hardening is not.

## Plugins

| Repository | Declares `camaleon_cms` | Last activity | Binds to |
|---|---|---|---|
| `cama_contact_form` | Gemfile, unpinned | 2026-08 | `admin_menu_append_menu_item` with a pre-rendered `datas` string; `cama_tmp_upload` into `public/contact_form/<site_id>` with no `formats`, from an unauthenticated endpoint; `cama_send_email` with `attachments`/`extra_data`; own copies of the content-safety patterns |
| `camaleon-cms-seo` (`cama_meta_tag`) | no | 2023-07 | `seo` hook reading `@cama_visited_post` and `is_page?`/`is_category?`/`is_post_type?`; `set_multiple_options(params[:options].permit!.to_h)` from six save hooks; `plugin_view` at both arities; runtime probe for Camaleon ≤ 2.3.6 |
| `camaleon-ecommerce` | `>= 2.4` | 2024-08 | **Two-arg `post_type_list_taxonomy`** (live-broken on master); **HTML in an admin menu title** (`span`/`small` + order count); unvalidated `params[:return_to]` and `request.referer` into `login_user`; `email_late` writing a PDF to disk inline; `I18n.locale` mutated mid-request without `ensure`; meta scopes `currencies` and `_setting_ecommerce`; raw `object_class` string on `CamaleonCms::Meta` |
| `camaleon_editor` | no | 2024-08 | **Unloadable as published** — includes `PluginCamaleonEditorPrivateHelper`, defined nowhere; all six declared hooks have no handler. Also `grid-editor.js` calls jQuery UI `$.fn.draggable({connectToSortable})` and reads `ui.helper`/`ui.placeholder` in sortable callbacks — **withdrawn** by #1169's jQuery UI removal (bundle jQuery UI downstream) |
| `cama_subscriber` | no | 2024-06 | `admin_menu_insert_menu_before` with nested `items`; three `cama_send_email` calls with `from`/`cc_to` (array)/`template`/`layout_name`; `CamaleonCms::Site.class_eval`; `CamaleonCms::Metas` on its own model; `all_locales` in a route constraint. Also calls `Rails.application.secrets`, removed in Rails 7.2 |
| `camaleon_sitemap_customizer` | `~> 2.0` | 2022-01 | `on_render_sitemap` accumulating into all four skip lists and overriding `args[:render]` — matches the contract #1223 restored; six post/plugin hooks; ActiveJob ping |
| `camaleon_image_optimizer` | `~> 2.0` | **2025-07** | `before_upload` only — rewrites the file in place and rebinds `settings[:uploaded_io]`, **after** the content scan; re-fires on the crop path's re-entry into `upload_file` |
| `camaleon_lazy_loader` | `~> 2.0` | 2022-01 | Writes `response.body`; shares `@skip_lazy_loader` across hooks; reads `front_cache`'s private `@_plugin_do_cache`; binds `on_render_sitemap` with an arity-1 handler that ignores the payload |
| `camaleon_export_import` | no gemspec (drop-in folder) | 2016-09 | Heaviest consumer found: seven `class_eval` patches from `app_before_load`; writes `content`, `content_filtered`, `user_id`, `post_class` from uploaded JSON; `cama_tmp_upload(params[:url])` with no options, path round-tripped to the client; hard-codes the `object_class` string grammar in five places; `posts.destroy_all`/`nav_menus.destroy_all` on client flags |
| `camaleon-post-clone` | no | 2016-12 | `deep_clone` + `save!` of a core Post, copying `content` verbatim; `set_field_values(params[:field_options])` unfiltered; `add_custom_field_group`/`add_manual_field`; renders the core partial `camaleon_cms/admin/settings/custom_fields/render` |
| `camaleon_post_created_at` | **`>= 2.3.5`** (only explicit constraint) | 2016-11 | Reads the controller ivar `@post` inside `new_post`/`edit_post`; appends raw HTML to `args[:extra_settings]`; injects `post[created_at]` into core strong params |
| `camaleon-post-order-plugin` | no | 2019-12 | `list_post` hook calling `append_asset_libraries` + `cama_content_append`; `update_column('post_order')` direct on core posts; JS hard-coupled to the admin post-list DOM (`#posts-table-list`, `tr[data-id]`) |
| `cama_external_menu` | no | 2018-10 | `on_external_menu` sets `args[:parsed_menu] = false` — the entire access check, and it **fails open**; calls bare `current_user` and `.role` |
| `camaleon_oauth` | no | 2016-09 | Includes `SessionHelper`/`SiteHelper`/`HooksHelper` into `Object`; signs in via Doorkeeper `resource_owner_from_credentials` → `login_user_with_password` return value; identity read back through core's own `doorkeeper_token` branch. **Never assigns `@cama_current_user`** |
| `camaleon-spree` | commented out in gemspec | 2017-10 | Reopens `CamaleonCms::SessionHelper` to replace `cama_current_user` and the login/register/logout path helpers; `class_eval` on `FrontendController`, `AdminController`, `User`; redefines `CamaleonCms::PostDecorator`; injects its admin menu via `cama_content_prepend` + DOM selectors; `add_after_reload_routes`; needs `user_model: Spree::User` |
| `camaleon_admin_ajax` / `admin-ajax` | no | 2022-08 | **Unloadable as published** — `PluginCamaleonAdminAjaxPrivate` absent. Globally patches `ActionController::Redirecting#redirect_to`. Deep JS contract: `#admin_content[data-url]`, `#sidebar-menu`, `showLoading`/`hideLoading`, `I18n()`, and "response must not start with `<!DOCTYPE html>`". Calls `PluginRoutes.system_info_set`, absent from core |
| `cama_tinymce_template` | no | 2017-03 | No Ruby coupling at all; one `admin_before_load` → `append_asset_libraries`. Entire contract is the JS globals `tinymce_global_settings["settings"]`/`["setups"]` and `open_modal(...)` — documented in its README as the extension point for theme authors |
| `camaleon_cms_rating` | no | 2017-08 | `class_eval` `has_many :ratings` onto `CamaleonCms::Post`; own table, not metas; reads `static_system_info['user_model']` at load time. Ajax payload carries no `user_id` — rater derived server-side |
| `camaleon-download` | no | 2019-01 | `admin_menu_insert_menu_after`; `shortcode_add` with unescaped attribute interpolation; calls `CamaleonCmsLocalUploader.private_file_path`, **absent from core**; `return_to` on the login path; PostgreSQL-only (`jsonb`) |
| `cama_image_lightbox` | no | 2016-12 | `shortcode_add` from `app_before_load`; `append_asset_libraries` with `plugin_asset`; `String#cama_parse_image_version` |
| `cama-stripe-donation` | no | 2024-08 | `CamaleonCmsLocalUploader.private_file_path` with a Base64-decoded request parameter, then `send_file`; `current_plugin.get_option` from a view; `@plugin.get_option` from controllers; reopens `CamaleonCms::Site` |
| `camaleon-cms-language-editor` | no | 2020-09 | `plugin_asset_path` single-arg; reaches into `I18n.backend`'s private `translations` hash; writes to `params` from a view |

## Themes

| Repository | Last activity | Binds to |
|---|---|---|
| `cama-ecommerce-theme` (E Shop) | 2016-12 | `cama_menu_parse_items(nav_menu.children)` with implicit ordering; 48 `append_menu_item` calls on activation; `cama_current_user` decorated and undecorated; absolute `site_current_url` as `return_to`; JS globals `load_upload_image_field`, `cama_get_tinymce_settings` |
| `camaleon-cms-efashion` | 2016-09 | Live `select_eval` field created on activation (**now raises under the permission gate**); unguarded `nav_menus.find_by_slug('main_menu').children`; same JS globals |
| `camaleon-cms-shoppy` | 2016-07 | Live `select_eval`; `set_field_values(params[:field_options])` with no guard; 23 `current_theme.the_field` reads; assigns an ivar inside a view |

## Host applications

| Application | Camaleon | Shape | Notes |
|---|---|---|---|
| `camaleon_website` (camaleon.website) | 2.9.2 | **Wildcard-subdomain multisite**, 10 plugin gems pinned to git SHAs, 3 vendored plugins, 8 vendored themes | Runs `raise_on_open_redirects = false` with a comment waiting on a core `cama_site_check_existence` fix; `manifest.js` hard-codes gem asset logical paths, so asset renames break its build; four `class_eval` patches on `CamaleonCms::Site`/`User`; four `cama_send_email` call sites; a theme shortcode emitting a raw `<script>` |
| `florsan` (florsan.md) | 2.9.2 | Single site, **three locales (en/md/ru)**, one vendored theme, no plugin gems | Zero `CamaleonCms::` references and zero monkey patches — the cleanest consumer surveyed. System-level `on_uploader`/`uploader_aws_before_upload` hooks that share `@suppress_content_type` across the pair; `on_render_sitemap` mutating `lookup_context.formats`; no YAML locale files, all translations in the database |

## Hardening hazards

Changes that look free from inside this repository and are not:

- **Removing jQuery UI from the admin bundle** (#1169) leaves only `$.fn.sortable`/`disableSelection`
  (a SortableJS shim) and Awesomplete for autocomplete. `camaleon_editor`'s grid editor calls
  `$.fn.draggable` and reads `ui.helper`/`ui.placeholder`, with no jQuery UI of its own — disposition:
  **withdrawn** (a host must bundle jQuery UI). The other widgets (datepicker/dialog/resizable/…) have
  no surveyed consumer; `camaleon-ecommerce`'s `.datepicker()` is bootstrap-datepicker, not jQuery UI.
- **Escaping admin menu titles** breaks `camaleon-ecommerce`'s Orders entry.
- **Filtering the menu `datas` value** must tolerate a pre-rendered single-quoted attribute string —
  the current filter truncates values at an embedded quote, which already breaks the engine's own
  Menus tooltip.
- **Requiring `cama_permitted_field_options`** breaks four plugins that pass raw params to
  `set_field_values`.
- **Restricting upload `formats` by default** breaks `cama_contact_form`'s file fields.
- **Validating `cama_tmp_upload` paths against `public/`** breaks `cama_contact_form`'s redisplay URL.
- **Making `hooks_run` dispatch off the controller** breaks seven plugins, one of them silently and
  one of them open (`cama_external_menu`).
- **Moving mail to a background job** breaks `camaleon-ecommerce`'s `email_late` PDF path and drops
  its mid-request locale.
- **Renaming gem-side assets** breaks `camaleon_website`'s production precompile.
- **Host-checking `login_user`'s `redirect_url` and the session flows' `return_to`** (#1258) drops an
  off-site post-login/registration redirect. Surveyed consumers that feed these: `camaleon-ecommerce`
  (unvalidated `params[:return_to]`/`request.referer` into `login_user`) and `camaleon-download` (`return_to`
  on the login path); a same-site value like `cama-ecommerce-theme`'s `site_current_url` is unaffected, and
  `camaleon_website` (which runs `raise_on_open_redirects = false`) had a live off-site leak here, now closed.
  An intentional off-site destination is restored via the `redirect_allowed_hosts` option /
  `safe_redirect_hosts` hook, or a hook's `allow_external_redirect` — see `docs/security/permissions.md`.

- **Converting admin GET routes to PATCH/POST** (M6) is invisible to every surveyed consumer except
  **logout**, which five theme layouts (`cama-ecommerce-theme`, `efashion`, `shoppy`, and the two
  bundled themes), both host apps, and `camaleon_website`'s store plugin (`redirect_to
  cama_admin_logout_path`) reach over GET — two of them with `return_to:`. That is why
  `GET /admin/logout` stays routable and renders a POST confirmation instead of 404ing like the
  other converted paths; the confirmation carries `full`, `return_to` and `locale` through as
  scalars (a malformed hash-shaped parameter is dropped, not a 500), answers any requested format
  with HTML, and a stale-token POST re-renders it — so an odd ecosystem link degrades to an extra
  click, never an error page. `camaleon-spree` replaces the logout path helpers and is unaffected;
  `plugins/toggle` appears only in two plugins' localhost integration tests; the review round's
  `load_data` narrowing (theme sample-data import, GET dropped) has **no caller in core or any
  surveyed repository**. The theme generator now scaffolds the logout `button_to`, so newly
  generated themes start on the POST pattern. Follow-up 2's JS-coupled trio is equally invisible:
  nav-menu `item_delete` (now DELETE) is called only by core's own `nav_menu.js`; the legacy
  `widgets`/`widget_delete` routes (GET dropped, non-GET verbs and helpers kept) point at a
  controller deleted in 2015, and no surveyed repository references them or supplies the missing
  controller; `media/crop` (now POST-only) has **no caller anywhere** — the admin cropper POSTs
  `crop_url` to `media#actions`, and the only crop-adjacent ecosystem file is `camaleon_website`'s
  vendored `croppic.js`, never instantiated (and it would POST).

- **Correcting the media `is_public` semantics** (#1286) is invisible to every surveyed consumer:
  none reads `media.is_public` or `Site#public_media`/`#private_media` directly (the two plugins
  touching private media go through `CamaleonCmsLocalUploader.private_file_path`, and access
  control keys off the uploader mode, not the flag). An *unsurveyed* consumer reading them
  directly was getting inverted answers on every install since 2018 — after the
  `camaleon_cms:repair_media_visibility` run it gets correct ones, and a compensating inversion
  must be dropped (called out in `docs/upgrading-to-2.9.5.md`). The same change's hardening is
  behavior downstream can observe: `add_file` without `same_name: true` now renames on a
  storage-level collision even when no cache row exists; `objects(prefix)` returns an empty
  relation instead of `nil` for an unknown folder; `clear_cache` purges both visibility
  collections.

- **Requiring a CSRF token on `media#upload`** (M7) is invisible to every surveyed consumer: no
  repository POSTs to core's `media#upload` with its own transport. `camaleon_editor` reaches uploads
  through core's own `input_upload_field` → `upload_filemanager` → the same `uploadFile` instance, so
  the token fix (an `authenticity_token` form field on the multipart POST, since that transport
  bypasses jquery_ujs' ajax prefilter) covers it; the `file_upload` matches in `camaleon_website`'s
  store plugin and `florsan` are their own upload flows, not core's endpoint. Any external script
  that posted there without a token must now send one.

- **`set_field_values` deriving `custom_field_id` from the slug** (review follow-up) touches a public
  model API plugins may call directly. Each value row's `custom_field_id` now comes from the field
  the submitted slug names, not the caller-supplied `id`. A plugin passing the browser payload shape
  (`{group => {slug => {id:, values:}}}`) is unaffected — its `id` already matches the slug; only a
  caller that deliberately paired a slug with a *different* field's id sees a change (it gets the
  slug's field id). The plugin generator template now routes `field_options` through the same
  `cama_permitted_field_options` allow-list core uses, so freshly generated plugins no longer ship
  the pre-M8 unfiltered save.

## APIs with no surveyed consumer

Safe to change on the engine's own merits, citing this file: `update_or_create` / `update_or_create!`
/ `assign_or_new` / `ActiveRecordExtras`; `find_by_key`; `unassign_category` / `assign_tags` /
`unassign_tags`; `update_counters`; `cf_add_model`; `@_admin_menus`; `@cama_current_user` (no external
writer); `on_translation`; `render prefixes:`; `Widget::Assigned` discriminator literals; `user_model`
beyond the two read sites above; `SUSPICIOUS_PATTERNS` / `UNSAFE_EVENT_PATTERNS`; `post_type_list_taxonomy`
at any arity other than two.

## Engine APIs called but missing

Consumers are already broken against master. Restoring any of these is a decision, not a bug fix:

- `CamaleonCmsLocalUploader.private_file_path` — `camaleon-download`, `cama-stripe-donation`. The
  latter passes a request-supplied path, so a naive restoration restores a traversal with it.
- `PluginRoutes.system_info_set` — `camaleon_admin_ajax`.
- `current_site.contact_forms` — `camaleon_oauth`; supplied by the `cama_contact_form` gem, not core.
