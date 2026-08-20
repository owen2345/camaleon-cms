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
- Untrusted input follows the remedy rule: dangerous content is **rejected** at save with an error — never sanitized, stripped, or otherwise transformed (no render-time sanitization either). See `docs/security/permissions.md` ("The remedy rule").
- Security-sensitive actions follow the gating rule: admin-only by default, gated for non-admins by a dedicated, off-by-default, fail-closed permission — never a path/filename/flag proxy, never fail-open. See `docs/security/permissions.md` ("The gating rule") and the `security-capability-gating` spec.

## Rails Conventions

- Controllers use strong parameters
- Models have proper associations and validations
- Views use helpers instead of logic

## Camaleon CMS Specific

- Plugins/themes follow the established patterns
- Hooks are used for extensibility
- Custom fields are handled correctly
