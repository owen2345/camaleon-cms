# Tasks: correct-media-is-public-flag

## 1. Reproducing specs (write first, watch them fail on master's routing)

- [x] 1.1 Add `spec/uploaders/media_collection_routing_spec.rb`: a private uploader
  (`private: true`) resolves `get_media_collection` to `site.private_media` and a row cached
  through it persists `is_public: false`; a public uploader resolves to `site.public_media` and
  persists `is_public: true`; `site.public_media` returns only genuinely public rows. On master
  these assertions fail (the mode maps to the opposite collection).
- [x] 1.2 Add `spec/lib/tasks/media_is_public_backfill_rake_spec.rb`: seed rows with mixed
  `is_public`, invoke `camaleon_cms:backfill_media_is_public`, assert every non-NULL row's flag
  inverted; a second `invoke` (after `reenable`) is a no-op (values unchanged) and reports already
  done; a `NULL is_public` row is left NULL.

## 2. Implementation

- [x] 2.1 `app/uploaders/camaleon_cms_uploader.rb`: flip the `get_media_collection` ternary to
  `is_private_uploader? ? @current_site.private_media : @current_site.public_media`; replace the
  "inverted / do not swap" note with a plain description plus a pointer to the back-fill task for
  existing installs.
- [x] 2.2 Add `lib/tasks/media_is_public_backfill.rake` (`camaleon_cms:backfill_media_is_public`):
  guard on a `media_is_public_backfill_v1` marker meta on `Site.reorder(id: :asc).first`; inside
  one `ActiveRecord::Base.transaction`, `update_all('is_public = NOT is_public')` over
  `CamaleonCms::Media` and write the marker; report counts via `CamaleonCms::TaskReporter`; no-op
  with a clear message when the marker already exists or no site exists.
- [x] 2.3 Do NOT touch `app/models/camaleon_cms/site.rb` scopes or `app/models/camaleon_cms/media.rb`
  (already correct — see design.md).
- [x] 2.4 Update `spec/uploaders/local_uploader_spec.rb` and
  `spec/requests/admin/media_controller/index_spec.rb`: drop the explicit `is_public: false` on
  rows built through the (public) uploader's `get_media_collection`, so each row inherits the
  collection's scope value and `objects('/')` still finds it.

## 3. Verification & bookkeeping

- [x] 3.1 Full CI parity locally: `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 CHANGELOG.md entry (newest-first) describing the corrected flag and the **mandatory**
  `camaleon_cms:backfill_media_is_public` upgrade step and its deploy ordering.
- [ ] 3.3 Maintainer sign-off (behaviour/data-sensitive), then `/opsx:verify` and `/opsx:archive`
  on the branch before merge (archive commit is part of the PR).
