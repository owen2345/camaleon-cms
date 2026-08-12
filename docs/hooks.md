# Hooks

Camaleon's extension mechanism: core fires named hooks at defined points, and plugins/themes register
handlers that run there. This file is the **repo-verified** counterpart to the (older) hooks page at
<https://camaleon.website/documentation/category/40758-modules/hooks-1.html>, which carries prose
descriptions but has drifted from the code — verify anything there against a call site before relying on it.

**Inventory generated 2026-08-13** from master `18b7e90b` — 130 distinct hooks, from every call site of the
two dispatch forms (see Mechanism). The list is a snapshot; the command is the source of truth — regenerate
it (BSD/macOS `grep`; on GNU `grep` `[[:space:]]` works too):

```bash
{ grep -rhoE "hooks?_run\(['\"][a-z0-9_]+['\"]" app lib | sed -E "s/.*\(['\"]//; s/['\"].*//"
  grep -rhoE "hook_run\([^,]+,[[:space:]]*['\"][a-z0-9_]+['\"]" app lib | sed -E "s/.*,[[:space:]]*['\"]//; s/['\"].*//"
  grep -rhoE "run_hook_lifecycle\(['\"][a-z0-9_]+['\"]" app lib | sed -E "s/.*\(['\"]//; s/['\"].*//"; } | sort -u
```

## Mechanism

**Register** a handler by mapping the hook to one or more helper methods in a plugin/theme's
`config/config.json`; the helper class is declared under `"helpers"`:

```json
"helpers": ["Plugins::MyPlugin::MainHelper"],
"hooks":   { "after_login": ["my_after_login"] }
```

**Handle** it by defining that method in the helper. A handler takes a single `args` value — a Hash for
most hooks — and communicates back by **mutating it in place**:

```ruby
# in Plugins::MyPlugin::MainHelper
def my_after_login(args)
  args[:redirect_to] = my_dashboard_url
end
```

**Register programmatically** (no manifest), e.g. from an initializer:

```ruby
PluginRoutes.add_anonymous_hook('after_login', ->(args) { args[:redirect_to] = '/welcome' })
```

**Trigger** (core/engine side, shown for reference — plugins rarely do this) takes two forms:
`hooks_run('name', args)` broadcasts to every enabled plugin/theme (plus any anonymous hooks), while
`hook_run(target, 'name', args)` runs the handler of one specific plugin/theme's settings — used for
theme/plugin-scoped hooks such as `theme_options`, `plugin_options` and the `on_active`/`on_inactive`/
`on_upgrade` lifecycle. `app_*_load` and `admin_*_load` fire through the `run_hook_lifecycle` wrapper.
Every registered handler runs in turn on the same `args`, so ordering across plugins is not guaranteed:
a handler should add to or adjust `args`, not assume it is the only one. There is no
`HooksManager.add_listener` (a stale example named it; it does not exist).

## Session & authentication hooks

The hooks around login, registration and the post-auth redirect — including the two that gate off-site
redirects (see [security/permissions.md](security/permissions.md#security-off-site-redirect-allowlist)).
Argument shapes are read from the call sites in
`app/controllers/camaleon_cms/admin/sessions_controller.rb` and `app/helpers/camaleon_cms/session_helper.rb`:

| Hook | Fires | `args` keys (mutate these) |
|---|---|---|
| `session_before_load` / `session_after_load` | around every admin session action | none (notification only) |
| `user_before_login` | before authenticating a login | `:user`, `:params`, `:password`, `:captcha_validate`, `:stop_process` (set true to halt) |
| `after_login` | after a successful login, before redirect | `:user`, `:redirect_to` (destination), `:allow_external_redirect` (vouch for an off-site destination) |
| `user_before_register` | past the register captcha, before saving | `:user` (unsaved), `:params`, `:stop_process` (set true to veto the registration) |
| `user_after_register` | after the new user is saved | `:user`, `:message`, `:redirect_url` |
| `user_registered` | after registration, before redirect | `:user`, `:redirect_url`, `:allow_external_redirect` (vouch for an off-site destination) |
| `safe_redirect_hosts` | when vetting an off-site redirect target | `:hosts` (append trusted hostnames) |

`after_login`, `user_registered` and `safe_redirect_hosts` are the extension points for the off-site
redirect allowlist/opt-in; the policy they feed is specified in
`openspec/specs/session-return-redirects/spec.md`.

## Full inventory (core-fired hooks)

Grouped by subsystem; names only — read the call site (grep the name under `app/`, `lib/`) for the exact
`args`. This is the 2026-08-13 snapshot; the grep command above is authoritative.

**Sessions & users:** `session_before_load`, `session_after_load`, `user_before_login`, `after_login`,
`user_login_form`, `user_before_register`, `user_after_register`, `user_registered`, `user_register_form`,
`user_new`, `user_create`, `user_created`, `user_edit`, `user_update`, `user_updated`,
`user_update_more_actions`, `user_update_more_actions_form`, `user_after_edited`, `user_destroyed`,
`available_user_roles_list`, `safe_redirect_hosts`

**Posts & drafts:** `new_post`, `edit_post`, `create_post`, `created_post`, `update_post`, `updated_post`,
`destroy_post`, `destroyed_post`, `trashed_post`, `restored_post`, `filter_post`, `list_post`,
`list_post_extra_columns`, `post_can_visit`, `post_the_title`, `post_the_content`, `post_the_excerpt`,
`post_the_thumb`, `post_form_custom_html`, `post_form_sidebar_custom_html`, `post_get_list_templates`,
`post_get_list_layouts`, `posts_form_custom_fields_render`, `create_post_draft`, `created_post_draft`,
`update_post_draft`, `updated_post_draft`

**Post tags:** `before_create_post_tag`, `after_create_post_tag`, `before_update_post_tag`,
`after_update_post_tag`, `before_destroy_post_tag`, `before_show_post_tag`, `before_list_post_tags`

**Post types:** `post_type_settings_admin`, `post_type_settings_form`, `post_type_settings_front`,
`created_post_type`, `updated_post_type`

**Categories & taxonomy:** `create_category`, `created_category`, `update_category`, `updated_category`,
`category_form`, `category_list_header`, `category_list_body`, `list_category`, `taxonomy_the_title`,
`taxonomy_the_content`, `taxonomy_the_excerpt`

**Media, uploads & files:** `before_upload`, `after_upload`, `on_uploader`, `on_uploader_resize`,
`uploader_local_before_upload`, `uploader_aws_before_upload`, `uploader_list_objects`, `before_crop_image`,
`before_resize_crop`, `file_manager_edit_file`, `file_manager_del_file`, `after_delete`

**Rendering & frontend:** `front_before_load`, `front_after_load`, `front_default_layout`,
`front_cache_reading_cache`, `front_cache_writing_cache`, `on_render_index`, `on_render_post`,
`on_render_post_type`, `on_render_post_tag`, `on_render_category`, `on_render_profile`, `on_render_search`,
`on_render_rss`, `on_render_robots`, `on_render_sitemap`, `on_render_draft_permitted`,
`on_render_front_menu_item`, `on_dashboard`, `on_ajax`, `on_notification`, `admin_notifications`

**Menus:** `on_external_menu`, `menu_external_form`, `nav_menu_custom`, `parse_custom_menu_item`

**App, admin & plugin/theme lifecycle:** `app_before_load`, `app_after_load`, `admin_before_load`,
`admin_after_load`, `on_active`, `on_inactive`, `on_upgrade`, `on_theme_settings`, `theme_options`,
`plugin_options`, `plugin_after_install`, `plugin_after_uninstall`, `plugin_after_upgrade`,
`plugin_after_destroy`

**Custom fields, i18n, email & sites:** `custom_field_custom_models`, `extra_custom_fields`,
`draw_custom_assets`, `seo`, `on_translation`, `email`, `email_late`, `list_site`
