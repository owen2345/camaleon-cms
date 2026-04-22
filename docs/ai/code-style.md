# Code Style Guide

## Linting

```bash
bundle exec rubocop
```

## General Formatting

- **2-space indentation** (not tabs)
- **UTF-8 encoding**
- **Unix line endings** (LF)
- **Frozen string literals**: `# frozen_string_literal: true` at top of Ruby files
- **Max line length**: 120 chars (from rubocop todo)

## Controller exception handling

```ruby
rescue_from CanCan::AccessDenied do |exception|
  flash[:error] = "Error: #{exception.message}"
  redirect_to cama_admin_dashboard_path
end
```

## Immutability

- Prefer `defined?` checks for memoization
- Avoid mutation of method parameters
- Use `dup` when needing a mutable copy
