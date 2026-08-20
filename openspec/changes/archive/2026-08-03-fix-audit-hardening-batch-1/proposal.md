# Proposal: fix-audit-hardening-batch-1

## Why

A full regression audit of `2.9.2..master` confirmed twelve high-severity regressions; the six
smallest were fixed in PR #1223 as surgical restorations of 2.9.2 behavior. Each restored behavior
is a durable contract (boot resilience, plugin compatibility, search, sitemap, sign-in) that had no
spec-level requirement, which is exactly why it could regress silently — CI never exercised the
configurations involved. This change pins them as requirements.

## What Changes

- Engine boot no longer depends on `ActionDispatch::Static` being present: the media
  security-headers middleware is inserted conditionally, so hosts with `public_file_server`
  disabled (nginx/Apache serving `public/`) boot again.
- `PluginRoutes.all_helpers` / `site_plugin_helpers` tolerate installed plugins and themes that
  declare no `helpers` key — the lists no longer carry `nil` entries that crashed
  `CamaleonController` at class load.
- `CamaleonCms::CamaleonHelper` is included in the controller chain again, restoring the
  controller-context surface (`ct`, `cama_t`, `cama_cache_fetch`, …) that `GET /search`, plugin
  hook functions, and `current_plugin` rely on.
- Frontend search builds its SQL pattern from the downcased query and honors an empty result set
  supplied by the `on_render_search` hook.
- The HTML sitemap generator applies its default skip lists correctly (guard was inverted) and the
  default-theme template passes the `on_render_sitemap` hook config through again.
- Login, password reset, and `site.the_user(username)` use the custom lowercasing finders
  `find_by_username` / `find_by_email` again, restoring case-insensitive lookups on
  case-sensitive collations.

None are breaking: every item restores documented or long-standing 2.9.2 behavior.

## Capabilities

### New Capabilities

- `plugin-helper-registration`: which helper declarations installed plugins/themes may omit, and
  what `PluginRoutes` helper lists may contain.
- `frontend-search-matching`: case-insensitive query matching and the `on_render_search` hook
  override contract for the frontend search action.
- `html-sitemap-rendering`: the HTML sitemap renders the category tree and honors the
  `on_render_sitemap` skip lists.
- `case-insensitive-credential-lookup`: username/email lookups for login, password reset, and
  `the_user` are case-insensitive given downcased storage.

### Modified Capabilities

- `media-serving-security`: the SVG security-headers middleware SHALL be installed under both
  static-file-server configurations, and its installation SHALL NOT abort boot when
  `ActionDispatch::Static` is absent.
- `frontend-controller-helper-compatibility`: the controller-context helper surface extends to
  `CamaleonHelper`'s methods on `CamaleonController` and all subclasses (frontend, admin, and
  plugin controllers).

## Impact

- `lib/camaleon_cms/engine.rb` (middleware insertion), `lib/plugin_routes.rb` (helper lists)
- `app/controllers/camaleon_cms/camaleon_controller.rb` (helper include),
  `frontend_controller.rb` (search), `admin/sessions_controller.rb` (login/forgot lookups)
- `app/helpers/camaleon_cms/camaleon_helper.rb` (sitemap generator),
  `session_helper.rb` (password login), `app/decorators/camaleon_cms/site_decorator.rb`
  (`the_user`)
- `app/views/camaleon_cms/default_theme/sitemap.html.erb` (hook config pass-through)
- Regression specs added in PR #1223 under `spec/requests/frontend/`, `spec/lib/`,
  `spec/features/admin/`, and `spec/decorators/`.
