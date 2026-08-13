# Tasks

## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the policy decision — maintainer (2026-08-13): untrusted input is rejected, never
  sanitized; align post content with uploads, the contact form, and the custom-field gate

## 2. Reproduce first

- [x] 2.1 Rewrite `spec/models/post_content_sanitization_spec.rb` as
  `post_content_rejection_spec.rb`: every previously-stripped payload must now refuse the save;
  benign content must be stored byte-for-byte
- [x] 2.2 Confirm the rejection examples fail against the sanitize-era model (stash the fix, run,
  restore)

## 3. Fix

- [x] 3.1 Replace `Post#sanitize_content` with the `reject_untrusted_dangerous_content` validation
  (same guard, trust, opt-out and fail-closed semantics; error instead of mutation)
- [x] 3.2 Keep pre-gate stored content editable while `content` itself is untouched
- [x] 3.3 Add read-only `rake camaleon_cms:security:scan_content` listing stored content that would
  fail today's gates (posts + gated custom-field values)
- [x] 3.4 Confirm the reproduction passes (36 examples across the rejection specs)

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the rejection specs — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings (bundle-level pass before push)
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean (bundle-level pass before push)

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: dangerous post content is rejected on save
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
