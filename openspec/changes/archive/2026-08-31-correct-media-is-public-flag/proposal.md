## Why

`CamaleonCms::CamaleonCmsUploader#get_media_collection` routes the two uploader modes to the
wrong collections:

```ruby
is_private_uploader? ? @current_site.public_media : @current_site.private_media
```

A **private** uploader resolves to `public_media` (`where(is_public: true)`) and a **public**
uploader to `private_media` (`where(is_public: false)`). Because a record built through an
association scope inherits that scope's `where` value, every media row is persisted with
`is_public` set to the **opposite** of the file's real visibility.

The system is self-consistent only because every reader and writer of media rows goes through
this same routing, and access control keys off `is_private_uploader?` (the uploader mode /
storage path), never off the stored flag. But `is_public` is a public column with obvious
semantics, and any direct consumer of it reads the truth inverted: `@current_site.public_media`
returns the site's **private** files and vice versa, and any report, export, migration, or
future feature filtering on `is_public` gets the wrong set.

The defect predates the split media table (commit `2a0a2ae2`, 2018). It was flagged during the
PR #1285 max-effort review and left as a tracking task because the code fix and the stored data
must be corrected together.

## What Changes

- **Correct the write routing.** `get_media_collection` becomes
  `is_private_uploader? ? @current_site.private_media : @current_site.public_media`. This is the
  **only** wrong line: the association scopes and `Media#items` / `#create_parent_folders` are
  already correct and MUST NOT change (see design.md; flipping them too would cancel the fix).
- **Repair existing rows by rebuilding the cache from storage.** Media rows are a pure cache of
  storage, so `camaleon_cms:repair_media_visibility` purges cached rows (batched) and lets the
  cache rebuild through the corrected routing, deriving each flag from where the file actually
  lives. Convergent by construction — safe to re-run, concurrently, or on an already-correct
  database; no marker, no run-once guard. An in-place flip was rejected (design.md: it corrupts
  already-correct rows, mangles legacy SQLite text booleans, and every guard failure is
  destructive).
- **Harden the stale-cache seams the window exposes.** Upload name-collision checks consult
  storage as well as the cache (a missed collision silently overwrote stored bytes); file and
  folder deletes tolerate a missing cache row instead of 500ing after the storage delete; an
  unknown folder key renders an empty listing instead of crashing the media browser; the admin
  clear-cache purges both visibility collections. Each is correct independently of the repair —
  the cache can always be stale — and each is covered by its own spec.
- **Coordination requirement.** The repair task must run immediately after deploy, before further
  media activity. Documented in CHANGELOG (Notes for upgraders) and the task description; the
  task also heals rows damaged by media activity in the window, since it rebuilds from storage.

Non-goals:
- No change to access control, storage paths, or how private files are served — those key off the
  uploader mode, not `is_public`.
- No in-place transformation of media rows anywhere: the repair only deletes cache rows and lets
  the existing rebuild path recreate them (`is_public: NULL` legacy rows are purged and rebuilt
  validly along the way).

## Capabilities

### New Capabilities

- `media-visibility-flag-integrity`: the stored `media.is_public` flag reflects a file's real
  visibility, the `public_media` / `private_media` associations return the collection their name
  denotes, the uploader routes each mode to the matching collection, and a convergent repair
  task rebuilds the stored flags from storage.

### Modified Capabilities

<!-- none: model-api-compatibility (public_media.find_by_key == by_key) and local-media-pagination
     are unaffected — this change corrects which rows land in each collection, not the collection
     API those capabilities describe. -->

## Impact

- `app/uploaders/camaleon_cms_uploader.rb` (`get_media_collection` ternary; storage-aware
  `search_new_key`; nil-safe unknown-folder listing; both-collection `clear_cache`)
- `app/uploaders/camaleon_cms_local_uploader.rb`, `app/uploaders/camaleon_cms_aws_uploader.rb`
  (storage-existence collision checks; nil-safe deletes)
- `lib/tasks/media_visibility_repair.rake` (new convergent purge-and-rebuild repair)
- `spec/uploaders/media_collection_routing_spec.rb` (new: reproduces the inversion; covers the
  production `enable_private_mode!` transition)
- `spec/lib/tasks/media_visibility_repair_rake_spec.rb` (new: rebuild correctness, convergence,
  cloud-site purge)
- `spec/uploaders/local_uploader_spec.rb`, `spec/uploaders/aws_uploader_spec.rb`,
  `spec/requests/admin/media_controller/index_spec.rb` (hardening coverage; drop the
  now-inconsistent explicit `is_public: false` on rows built through a public uploader's
  collection)
- `CHANGELOG.md`
