## 1. Branch

- [x] 1.1 Work on the shared `security/tier2-hardening` branch (bundled Tier-2 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: the taxonomy filter replaces the post-type scope with the taxonomy owner's site-wide posts

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/post_index_post_type_scope_spec.rb`: a role with `edit_other` on A lists B's pending post via B's category id; plus a guard that A's own category still filters A's posts
- [x] 2.2 Confirm the leak example fails against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Intersect the taxonomy filter with the post type scope (`posts_all = posts_all.where(id: cat_owner.posts)` / `tag_owner.posts`) instead of replacing it
- [x] 3.2 Confirm the reproduction passes and legitimate same-post-type filtering is unchanged

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec spec/requests/security/post_index_post_type_scope_spec.rb` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: the admin post index no longer leaks another post type's posts via a taxonomy filter
- [ ] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
