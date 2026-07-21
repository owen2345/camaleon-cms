# Quality Criteria

Before marking any task complete, evaluate against these criteria.

## Code Quality

- Code passes RuboCop: `bin/rubocop`
- No new RuboCop violations introduced

## Testing

- Specs pass: `bin/rspec`
- New functionality has test coverage
- Bug fixes include a test that would have caught the bug

## Security

- No `eval`, `instance_eval`, or `class_eval` with user input
- SQL queries use parameterized forms
- User input is sanitized appropriately

## Rails Conventions

- Controllers use strong parameters
- Models have proper associations and validations
- Views use helpers instead of logic

## Camaleon CMS Specific

- Plugins/themes follow the established patterns
- Hooks are used for extensibility
- Custom fields are handled correctly
