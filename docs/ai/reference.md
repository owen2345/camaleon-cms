# Code Reference and Conventions for Camaleon CMS

Load this file when reading or writing application code.

## Baseline

- Ruby version target: infer from `.tool-versions`.
- Rails version target: infer from `Gemfile` and `Gemfile.lock`.
- Test framework: `rspec-rails` (see `docs/ai/testing.md`).
- Secrets: follow [`docs/ai/secrets.md`](./secrets.md) for what counts as a secret and how to handle it.

## Namespacing

Modules and classes are namespaced under `CamaleonCms`. The codebase defines `Cama::*` aliases for convenience:

```ruby
# Defined in config/initializers/model_alias.rb
Cama::Site     # = CamaleonCms::Site
Cama::Post     # = CamaleonCms::Post
Cama::Category # = CamaleonCms::Category
Cama::PostType # = CamaleonCms::PostType
```

## Key Paths

| Path | Purpose |
|------|---------|
| `spec/dummy/` | Test Rails application |
| `spec/support/` | Test helpers and shared configuration |
| `spec/factories/` | FactoryBot factory definitions |
| `app/apps/plugins/` | Plugins |
| `app/apps/themes/` | Themes |
| `config/routes/` | Split route files |
| `config/locales/` | Translation files |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RAILS_ENV` | Rails environment (test, development, production) |
| `DISABLE_DATABASE_ENVIRONMENT_CHECK` | Skip DB environment check |

## Models

- `CamaleonRecord` is the base class for Camaleon CMS ActiveRecord models (inherits from `ActiveRecord::Base`).
- Always specify `class_name` and `foreign_key` explicitly on associations.

## Decorators (Draper)

Located in `app/decorators/`:

```ruby
module CamaleonCms
  class PostDecorator < CamaleonCms::ApplicationDecorator
    delegate_all

    def the_title
      "#{object.title} - #{site.name}"
    end
  end
end
```

Common decorator methods:

```ruby
@object.decorate       # Returns decorated object
@object.the_title      # Decorated title
@object.the_url        # Decorated URL
@object.the_next_post  # Next post in sequence
@object.the_prev_post  # Previous post in sequence
```

- Admin pages can render frontend decorators and plugin helpers during preview flows.
- Preserve the `cama_get_i18n_frontend` / `cama_is_admin_request?` compatibility path when changing locale behavior around admin previews, especially for theme previews that render plugins such as `camaleon-ecommerce`.

## Controllers

Dynamic layout based on request type:

```ruby
layout proc { |_controller|
  params[:cama_ajax_request].present? ? 'camaleon_cms/admin/_ajax' : 'camaleon_cms/admin'
}
```

Exception handling:

```ruby
rescue_from CanCan::AccessDenied do |exception|
  flash[:error] = "Error: #{exception.message}"
  redirect_to cama_admin_dashboard_path
end
```

## Hook System

Camaleon CMS provides a hook system for plugin extensibility:

```ruby
# Trigger hooks
hooks_run('admin_before_load')
hooks_run('admin_after_load')

# Register hooks (in plugins)
CamaleonCms::HooksManager.add_listener(
  hook: 'admin_before_load',
  callback: -> { # do something }
)
```

Available hook points:
- `admin_before_load`, `admin_after_load`
- `frontend_before_load`, `frontend_after_load`
- `site_after_install`
- `post_after_save`, `post_before_destroy`

## Routes

Routes are split by scope in `config/routes/`:
- `config/routes/admin.rb`
- `config/routes/frontend.rb`
- `config/routes.rb`

## Plugin System

Plugins live in `app/apps/plugins/` and can:
- Add controllers (frontend and admin)
- Add helpers
- Add routes
- Hook into lifecycle events
- Add migrations

Compatibility notes:
- `CamaleonHelper#cama_is_admin_request?` is still a public plugin API. Keep it available for admin-rendered frontend flows such as theme preview pages that call plugin helpers like `camaleon-ecommerce`, where the plugin must detect admin preview mode instead of visitor/frontend mode.
- Frontend visited-state compatibility ivars (`@cama_visited_post`, `@cama_visited_category`, etc.) are still assigned by `FrontendVisitedStateConcern` for ecosystem compatibility, but are deprecated in favor of `CurrentRequest.frontend_visited_*`.
- Controller `@current_site` assignment is retained for legacy theme template rendering compatibility; new code should read site context from `current_site`/`CurrentRequest.site` instead of template-level ivar coupling.
- `ThemeHelper#theme_view` still accepts the legacy second argument for compatibility, but this call shape is deprecated; pass the view name as the first argument.

## Authorization

- Roles and permissions managed via `CamaleonCms::UserRole` and CanCanCan's `Ability` class
- Admins have all permissions by default
- Permissions are defined per site

## Assets and Test Database

- Uses **Dart Sass** via `dartsass-sprockets`
- Tests use SQLite; schema in `spec/dummy/db/schema.rb`
- Migrations run from both `db/migrate/` AND `spec/dummy/db/migrate/`

## Style Idioms (beyond RuboCop)

Formatting is enforced by RuboCop (`bin/rubocop -A`). Additional idioms:
- Prefer `defined?` checks for memoization
- Avoid mutation of method parameters
- Use `dup` when needing a mutable copy
