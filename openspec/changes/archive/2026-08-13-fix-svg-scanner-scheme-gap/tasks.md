## 1. Branch

- [x] 1.1 Create branch `security/svg-scanner-scheme-gap` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit: `unsafe?` accepts `java&#9;script:` (empirically + spec); the SVG scanner is the only gate for a served `.svg`

## 2. Reproduce first

- [x] 2.1 Add gap examples to `spec/lib/svg_content_checker_spec.rb`: TAB-gap href, auto-triggering animated gap href, newline-gap catch-all, plus a safe colon-bearing SVG that must stay accepted
- [x] 2.2 Confirm the three gap examples fail against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Reuse `ContentSecurity::BLOCKED_SCHEME_PATTERN` + `ContentSecurity.normalize` in both scheme checks (decoded `href` value and normalized serialized document)
- [x] 3.2 Confirm the reproductions now pass and safe SVGs are still accepted

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the SVG/upload-security specs and `spec/requests/security/` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: the SVG scanner's scheme checks gain the TAB/LF/CR gap tolerance the non-SVG ruleset has
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
