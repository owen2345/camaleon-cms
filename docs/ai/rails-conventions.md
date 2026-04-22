# Rails Conventions

## App Baseline
- Rails version target: `8.1.2`.
- Ruby version target: `3.4.8` (`.tool-versions`).
- Test framework: `rspec-rails`.

## Repo Rules
- Follow [`docs/ai/secrets.md`](./secrets.md) for what counts as a secret and how to handle it.

## Documentation Rules
- Keep runnable commands in `README.md` aligned with actual scripts/binaries.
- Keep integration evidence and mismatch notes in `docs/` files, not in commit messages.

### Layout Selection

Dynamic layout based on request type:
```ruby
layout proc { |_controller|
  params[:cama_ajax_request].present? ? 'camaleon_cms/admin/_ajax' : 'camaleon_cms/admin'
}
```

## Model Conventions

CamaleonRecord is used as a base class for the ActiveRecord models of Camaleon CMS
- inherits from `ActiveRecord::Base`

### Decorators (Draper)

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

### Association Options

Always specify class_name and foreign_key explicitly

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

## Route Conventions

Routes are split by scope in `config/routes/`:
- `config/routes/admin.rb`
- `config/routes/frontend.rb`
- `config/routes.rb`
