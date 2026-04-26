# Quality Criteria

Before marking any task complete, evaluate against these criteria.

## Criteria

### Code Quality
- Code passes RuboCop: `bundle exec rubocop`
- No new RuboCop violations introduced

### Testing
- Specs pass: `bin/rspec`
- New functionality has test coverage
- Bug fixes include a test that would have caught the bug

### Security
- No `eval`, `instance_eval`, or `class_eval` with user input
- SQL queries use parameterized forms
- User input is sanitized appropriately

### Rails Conventions
- Controllers use strong parameters
- Models have proper associations and validations
- Views use helpers instead of logic

### Camaleon CMS Specific
- Plugins/themes follow the established patterns
- Hooks are used for extensibility
- Custom fields are handled correctly

## Severity Levels

| Level | Meaning |
|-------|---------|
| blocking | Must fix before completing task |
| warning | Should fix, but not blocking |

## Adding New Criteria

When a failure pattern is found, propose a new criterion with:
- Specific, testable check
- Severity level
- Source (what prompted this)

Criteria that catch real issues repeatedly should be promoted to blocking.
