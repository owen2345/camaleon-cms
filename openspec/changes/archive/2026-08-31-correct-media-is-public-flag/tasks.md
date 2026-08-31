# Tasks: correct-media-is-public-flag

## 1. Reproducing specs (write first, watch them fail on master's routing)

- [x] 1.1 Add `spec/uploaders/media_collection_routing_spec.rb`: a row cached through a private
  uploader persists `is_public: false` and lands only in `site.private_media`; a public
  uploader's row persists `is_public: true` and lands only in `site.public_media`; the
  production `enable_private_mode!` / `disable_private_mode!` transition routes the same way.
  On master these assertions fail (the mode maps to the opposite collection).
- [x] 1.2 Add `spec/lib/tasks/media_visibility_repair_rake_spec.rb`: the task purges
  wrongly-flagged and phantom rows and rebuilds correct flags from storage; a repeat run
  reproduces the same state with no duplicates (convergence); a cloud-storage site is purged
  without touching its bucket.

## 2. Implementation

- [x] 2.1 `app/uploaders/camaleon_cms_uploader.rb`: flip the `get_media_collection` ternary to
  `is_private_uploader? ? @current_site.private_media : @current_site.public_media`; replace the
  "inverted / do not swap" note with a plain description plus a pointer to the repair task for
  existing installs.
- [x] 2.2 Add `lib/tasks/media_visibility_repair.rake` (`camaleon_cms:repair_media_visibility`):
  batched purge of all cached media rows, then eager public-cache rebuild for local sites via
  the corrected routing (private collections and cloud-storage sites rebuild lazily on their
  next browse); report via `CamaleonCms::TaskReporter`. Convergent — no marker, safe to re-run.
- [x] 2.3 Do NOT touch `app/models/camaleon_cms/site.rb` scopes or `app/models/camaleon_cms/media.rb`
  (already correct — see design.md).
- [x] 2.4 Update `spec/uploaders/local_uploader_spec.rb` and
  `spec/requests/admin/media_controller/index_spec.rb`: drop the explicit `is_public: false` on
  rows built through the (public) uploader's `get_media_collection`, so each row inherits the
  collection's scope value and `objects('/')` still finds it.
- [x] 2.5 Harden the stale-cache seams (each with its own spec): storage-aware collision checks
  in `search_new_key` (local disk / AWS HEAD); nil-safe `.take&.destroy` in the three bare
  delete paths; empty-relation fallback for an unknown folder key in `#objects`;
  both-collection purge in `#clear_cache`.

## 3. Verification & bookkeeping

- [x] 3.1 Full CI parity locally: `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 CHANGELOG.md entry (newest-first, ≤500 chars) with the **Notes for upgraders** step:
  run `camaleon_cms:repair_media_visibility` right after deploying, before further media
  activity.
- [x] 3.3 `/opsx:verify` the change, then `/opsx:archive` on the branch with the archive commit
  part of the PR; maintainer sign-off is exercised through PR #1286 review and merge
  (behaviour/data-sensitive change).
