## 1. Branch

- [x] 1.1 Create branch `security/aws-private-upload-acl` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit: `add_file` sends `acl: 'public-read'` unconditionally, so a private upload is world-readable at a guessable key

## 2. Reproduce first

- [x] 2.1 Add a private-mode example to `spec/uploaders/aws_uploader_spec.rb`: a private uploader's `add_file` must upload with `acl: 'private'`
- [x] 2.2 Confirm it fails against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Derive the ACL from `is_private_uploader?` in `add_file` (`'private'` when private, else `'public-read'`)
- [x] 3.2 Confirm the reproduction passes and the public-mode upload still uses `'public-read'`

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec spec/uploaders/` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: private-mode S3 uploads are stored owner-only
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
