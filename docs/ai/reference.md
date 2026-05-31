# Code References and conventions for Camaleon CMS

## Namespacing

Modules and classes are namespaced under `CamaleonCms`

## Model Aliases

The codebase uses `Cama::*` aliases for convenience:

```ruby
# Defined in config/initializers/model_alias.rb
Cama::Site    # = CamaleonCms::Site
Cama::Post    # = CamaleonCms::Post
Cama::Category # = CamaleonCms::Category
Cama::PostType # = CamaleonCms::PostType
```

## Key Paths

| Path | Purpose |
|------|---------|
| `spec/dummy/` | Test Rails application |
| `spec/support/` | Test helpers and shared configuration |
| `spec/factories/` | FactoryBot factory definitions |
| `app/apps/` | Themes and plugins |
| `config/locales/` | Translation files |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RAILS_ENV` | Rails environment (test, development, production) |
| `DISABLE_DATABASE_ENVIRONMENT_CHECK` | Skip DB environment check |

## Common Decorators

```ruby
@object.decorate       # Returns decorated object
@object.the_title      # Decorated title
@object.the_url        # Decorated URL
@object.the_next_post  # Next post in sequence
@object.the_prev_post  # Previous post in sequence
```

## Asset Pipeline

- Uses **Dart Sass** via `dartsass-sprockets`

## Test Database

- Uses SQLite for tests
- Schema in `spec/dummy/db/schema.rb`
- Migrations run from both `db/migrate/` and `spec/dummy/db/migrate/`

## Plugin System

Plugins live in `app/apps/plugins/` and can:
- Add controllers (frontend and admin)
- Add helpers
- Add routes
- Hook into lifecycle events
- Add migrations

Compatibility note:
- `CamaleonHelper#cama_is_admin_request?` is still a public plugin API. Keep it available for admin-rendered frontend flows such as theme preview pages that call plugin helpers like `camaleon-ecommerce`, where the plugin must detect admin preview mode instead of visitor/frontend mode.
- Frontend visited-state compatibility ivars (`@cama_visited_post`, `@cama_visited_category`, etc.) are still assigned by `FrontendVisitedStateConcern` for ecosystem compatibility, but are deprecated in favor of `CurrentRequest.frontend_visited_*`.
- Controller `@current_site` assignment is retained for legacy theme template rendering compatibility; new code should read site context from `current_site`/`CurrentRequest.site` instead of template-level ivar coupling.
- `ThemeHelper#theme_view` still accepts the legacy second argument for compatibility, but this call shape is deprecated; pass the view name as the first argument.

## Authorization

- Roles and permissions managed via `CamaleonCms::UserRole` and CanaCanCan's `Ability` class
- Admins have all permissions by default
- Permissions are defined per site
