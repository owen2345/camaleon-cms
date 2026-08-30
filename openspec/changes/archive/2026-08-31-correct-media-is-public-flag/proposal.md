## Why

`CamaleonCms::CamaleonCmsUploader#get_media_collection` routes the two uploader modes to the
wrong collections:

```ruby
is_private_uploader? ? @current_site.public_media : @current_site.private_media
```

A **private** uploader resolves to `public_media` (`where(is_public: true)`) and a **public**
uploader to `private_media` (`where(is_public: false)`). Because a record built through an
association scope inherits that scope's `where` value, every media row is persisted with
`is_public` set to the **opposite** of the file's real visibility: private files store
`is_public: true`, public files store `is_public: false`.

The system is self-consistent today only because every reader and writer of media rows goes
through this same routing, and access control keys off `is_private_uploader?` (the uploader
mode / storage path), never off the stored flag. So there is no user-visible bug in the media
browser or in file serving. But `is_public` is a public column with obvious semantics, and any
direct consumer of it reads the truth inverted:

- `@current_site.public_media` returns the site's **private** files, and `private_media` returns
  the **public** ones — the associations are named for the opposite of what they contain.
- Any report, export, migration, or future feature filtering on `is_public` (or on those
  associations) gets the wrong set.

The defect predates the split media table (commit `2a0a2ae2`, 2018). It was flagged during the
PR #1285 max-effort review and left as a tracking task because it cannot be corrected by a code
edit alone: flipping the routing without inverting the already-stored rows would make the running
system look for each existing file in the collection it is *not* stored in.

## What Changes

- **Correct the write routing.** `get_media_collection` becomes
  `is_private_uploader? ? @current_site.private_media : @current_site.public_media`, so a private
  uploader stores/reads `is_public: false` and a public uploader `is_public: true`. This is the
  **only** code line that is wrong. The `public_media` / `private_media` association scopes and
  `Media#items` / `Media#create_parent_folders` (`is_public ? public_media : private_media`) are
  already correct — the scope name matches its filter, and a row's flag maps to the same-named
  collection — and MUST NOT change (see design.md; flipping them too would cancel the fix).
- **Back-fill existing rows.** A one-time rake task
  `camaleon_cms:backfill_media_is_public` inverts `is_public` on every existing media row so the
  stored flag matches real visibility, inside a single transaction, guarded by a marker so a
  second run is a no-op (a blind re-flip would re-invert correct data). Data back-fills are rake
  tasks, not migrations, per repo convention.
- **Coordination requirement.** The back-fill is mandatory and must run immediately after the
  code is deployed. Between deploy and back-fill, existing private files (still stored
  `is_public: true`) list under `public_media` and drop out of `private_media` — a media-browser
  *listing* inversion only; file serving and access control are unchanged because they never read
  the flag. Documented in CHANGELOG and the task description.

Non-goals:
- No change to access control, storage paths, or how private files are served — those key off the
  uploader mode, not `is_public`.
- Rows with a `NULL is_public` (possible only for data written before PR #1285's
  `inclusion: [true, false]` validation) are left untouched: `NOT NULL` is `NULL`, and a NULL row
  is a separate pre-existing orphaning concern, not part of the inversion.

## Capabilities

### New Capabilities

- `media-visibility-flag-integrity`: the stored `media.is_public` flag reflects a file's real
  visibility, the `public_media` / `private_media` associations return the collection their name
  denotes, and the uploader routes each mode to the matching collection.

### Modified Capabilities

<!-- none: model-api-compatibility (public_media.find_by_key == by_key) and local-media-pagination
     are unaffected — this change corrects which rows land in each collection, not the collection
     API those capabilities describe. -->

## Impact

- `app/uploaders/camaleon_cms_uploader.rb` (`get_media_collection` ternary + the explanatory note)
- `lib/tasks/media_is_public_backfill.rake` (new one-time, guarded back-fill)
- `spec/uploaders/media_collection_routing_spec.rb` (new: reproduces the inversion)
- `spec/lib/tasks/media_is_public_backfill_rake_spec.rb` (new: flips, runs once, leaves NULL)
- `spec/uploaders/local_uploader_spec.rb`, `spec/requests/admin/media_controller/index_spec.rb`
  (drop the now-inconsistent explicit `is_public: false` on rows built through a public uploader's
  collection)
- `CHANGELOG.md`
