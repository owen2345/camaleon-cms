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

## Authorization

- Roles and permissions managed via `CamaleonCms::UserRole` and CanaCanCan's `Ability` class
- Admins have all permissions by default
- Permissions are defined per site
