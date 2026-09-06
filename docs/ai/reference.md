# Code Reference and Conventions for Camaleon CMS

Load this file when reading or writing application code. Version floors are in `AGENTS.md`; test conventions in `docs/ai/testing.md`.

## Layout

- `app/apps/plugins/` and `app/apps/themes/` hold the plugins and themes bundled with the gem; most of the ecosystem lives in separate gems (`docs/ai/ecosystem.md`).
- `spec/dummy/` is the host Rails app for specs and for Rails commands; `Rails.root` in specs points there.
- Routes are split under `config/routes/` (`admin.rb`, `frontend.rb`) and joined by `config/routes.rb`.

## Namespacing

Everything is under `CamaleonCms::`. `config/initializers/model_alias.rb` defines the `Cama::*` shortcuts (`Cama::Site`, `Cama::Post`, `Cama::PostType`, …) and, when the host app sets `user_model`, replaces `CamaleonCms::User` with the host's class plus `CamaleonCms::UserMethods` — never assume `CamaleonCms::User` is the engine's own model.

## Models and data

- `CamaleonRecord` is the base class for the engine's ActiveRecord models. Give every association an explicit `class_name` and `foreign_key`.
- Data backfills and repairs are Rake tasks under `lib/tasks/` (`camaleon_cms:` namespace, e.g. `media_visibility_repair.rake`), never migrations: the schema has not changed since 2018 (`db/migrate/`, mirrored by `spec/dummy/db/schema.rb`, SQLite in tests), a migration would regenerate that `schema.rb`, and the engine appends its migrations to every host app's `db:migrate` — an operator runs a task deliberately and can re-run it.
- **The media table is a rebuildable cache.** Every `CamaleonCms::Media` column is derived from storage by the uploaders' `browser_files`/`file_parse`; nothing on a row is user-authored. Never repair rows by transforming them in place — purge and let the cache rebuild from storage, which is what `clear_cache`, lazy rebuild on browse and `rake camaleon_cms:repair_media_visibility` all rely on (an in-place transform cannot know which rows are already correct; the archived `2026-08-31-correct-media-is-public-flag` change's `design.md` has the argument). `media.is_public` and `Site#public_media`/`#private_media` mean what they say since #1286; access control never reads the stored flag — it keys off `is_private_uploader?` and the storage path. Uploaders reach private mode via `enable_private_mode!` on a public-constructed instance (the controller path); constructing with `private: true` skips `setup_private_folder` and leaves the storage root public, so keep it to base-class tests.

## Decorators

Draper decorators live in `app/decorators/camaleon_cms/`; the presentation methods views and themes call are prefixed `the_` (`the_title`, `the_url`, `the_content`, …). Admin pages render frontend decorators and plugin helpers during preview flows, so keep the `cama_get_i18n_frontend` / `cama_is_admin_request?` compatibility path when changing locale behavior around admin previews — theme previews render plugins such as `camaleon-ecommerce`.

## Hooks

`hooks_run('hook_name', args)` dispatches to handlers registered in a plugin's or theme's `config/config.json`: the helper class under `"helpers"`, the hook-to-method map under `"hooks"` (`app/apps/plugins/authoring_post/config/config.json` is a complete example). A handler receives one `args` hash and communicates back by mutating it in place; the caller reads it afterwards (`hooks_run('safe_redirect_hosts', r)`, then `r[:hosts]`). `PluginRoutes.add_anonymous_hook(name, ->(args) { … })` registers one without a manifest; there is no `HooksManager.add_listener`. The 130-hook inventory and the session/auth contracts are in `docs/hooks.md`.

## Public API compatibility

Kept on purpose for external plugins and themes; check `docs/ai/ecosystem.md` before removing any of it:

- `CamaleonHelper#cama_is_admin_request?` — admin-rendered frontend flows (theme previews calling plugin helpers) detect admin mode with it.
- The frontend visited-state ivars (`@cama_visited_post`, `@cama_visited_category`, …) are still assigned by `FrontendVisitedStateConcern`; new code reads `CurrentRequest.frontend_visited_*`.
- Controller `@current_site` stays assigned for legacy theme templates; new code reads `current_site` / `CurrentRequest.site`.
- `ThemeHelper#theme_view` still accepts the legacy second argument; pass the view name first.

## Authorization

Roles and permissions are `CamaleonCms::UserRole` plus CanCanCan's `Ability`, defined per site; admins pass every check. Anything security-sensitive follows the gating and remedy rules in `docs/security/permissions.md`.

## Style beyond RuboCop

Prefer `defined?` checks for memoization, do not mutate method parameters, and `dup` when a mutable copy is needed.
