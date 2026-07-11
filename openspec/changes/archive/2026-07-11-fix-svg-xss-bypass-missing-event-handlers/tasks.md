## 1. Extract shared security patterns

- [x] 1.1 Create `lib/camaleon_cms/content_security.rb` with `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` constants, adding `onbegin`, `onend`, and `onrepeat`
- [x] 1.2 Replace inline constants in `app/helpers/camaleon_cms/uploader_helper.rb` with `include` / reference to the new module
- [x] 1.3 Replace inline constants in `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` with `include` / reference to the new module

## 2. Add test coverage

- [x] 2.1 Create a test SVG fixture with `onbegin` event handler at `spec/support/fixtures/unsafe-svg-onbegin.svg`
- [x] 2.2 Add RSpec test cases in `spec/helpers/uploader_helper_spec.rb` that verify `onbegin`, `onend`, and `onrepeat` are detected and the upload is rejected
- [x] 2.3 Run the full test suite with `bin/rspec` and confirm all tests pass

## 3. Final verification

- [x] 3.1 Run `bin/rubocop -A` (lint)
- [x] 3.2 Run `bin/brakeman --no-pager` (security)
- [x] 3.3 Run `(cd spec/dummy && bin/rails zeitwerk:check)` (load verification)
- [x] 3.4 Run `bin/rspec` (full test suite)
