# Tasks: fix-content-sanitization-scope

## 1. Red specs

- [x] 1.1 Sanitization scope specs: untrusted table markup + `colspan` preserved;
  `id`/`style`/`target`/`rel` preserved while `onclick`/script-in-style neutralized
- [x] 1.2 Opt-out specs: `unfiltered_content!` stores raw content with no user context;
  no `unfiltered_content=` writer exists (mass assignment raises `UnknownAttributeError`)
- [x] 1.3 H10 feature spec: activating the bundled `camaleon_first` theme succeeds

## 2. Implementation

- [x] 2.1 Add `CONTENT_ALLOWED_TAGS`/`CONTENT_ALLOWED_ATTRIBUTES` (superset of the sanitizer
  default) and pass them from `Post#sanitize_content`; add the reader + `unfiltered_content!`
  bang enabler (no `=` writer) and early-return on it
- [x] 2.2 `cama_sanitize_translatable` accepts optional `tags:`/`attributes:` (default nil =
  current behavior)
- [x] 2.3 H10: replace the two `helper.capture` footer defaults in `camaleon_first/main_helper.rb`
  with the static HTML string literals

## 3. Verification and close-out

- [x] 3.1 Red→green; full gates (`bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`)
- [x] 3.2 PR + changelog entry (allowlist widening + opt-out + theme-activation fix)
- [x] 3.3 Archive this change on the branch as part of the PR
