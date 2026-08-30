# Design: correct-media-is-public-flag

## The fix is one line, not three

The tracking note (and the original review) named three edit sites: the `get_media_collection`
ternary and the two `has_many :public_media` / `:private_media` scopes. Working through the
routing shows only the **ternary** is wrong; the scopes are already correct and must stay.

Target end state (each independently true):

1. Private upload → stored `is_public: false`; public upload → stored `is_public: true`.
2. `site.public_media` returns `is_public: true` rows = genuinely public files.
3. `site.private_media` returns `is_public: false` rows = genuinely private files.
4. `Media#items` / `#create_parent_folders` (`is_public ? public_media : private_media`) send a
   row to the collection matching its own flag.

Current definitions measured against that:

| Site | Current code | Correct? |
|------|--------------|----------|
| Scope `public_media -> where(is_public: true)` | name "public" ⇔ filter `is_public: true` | ✅ already correct |
| Scope `private_media -> where(is_public: false)` | name "private" ⇔ filter `is_public: false` | ✅ already correct |
| `Media#items` / `#create_parent_folders` | `is_public ? public_media : private_media` | ✅ maps a row's flag to the same-named collection |
| `get_media_collection` | `is_private_uploader? ? public_media : private_media` | ❌ **inverted** — a private uploader writes into the public collection |

Only `get_media_collection` breaks the mapping. It is the sole write/read router that turns an
uploader *mode* into a collection, so it is where mode and flag are wired together — and it wires
them backwards.

### Why the scopes must NOT be flipped

The write path needs exactly **one** correction. There are two candidate levers, and flipping the
wrong one — or both — reintroduces the bug:

- **Flip the ternary only (chosen):** private uploader → `private_media` → `is_public: false`.
  Scope `public_media` keeps returning `is_public: true` = genuinely public rows. Consumer bug
  fixed. ✅
- **Flip the scopes only:** `public_media -> where(is_public: false)`. The stored values would come
  out right (private = false), but `site.public_media` would now *return private files* — the
  association name would contradict its contents, i.e. the exact consumer-facing bug we are
  fixing, just relocated. ❌
- **Flip the ternary AND the scopes:** the two inversions cancel. A private uploader → (flipped)
  `private_media` → (flipped) `where(is_public: true)` → stores `is_public: true` again. Back to
  today's inverted data. ❌

So: **ternary flips, scopes and `Media` stay untouched.**

## Back-fill: why a guarded one-shot

The code correction changes future writes; existing rows still hold the inverted value. A private
file stored as `is_public: true` is, after the fix, invisible to the private uploader (which now
reads `is_public: false`) and shows up under `public_media`. Correcting the data means inverting
`is_public` on every existing row exactly once.

- **Rake task, not a migration** — repo convention: data back-fills live in `lib/tasks/*.rake`; a
  migration would force a `schema.rb` regeneration for a pure data change.
- **Exactly once** — the operation is `is_public = NOT is_public`, which is its own inverse; a
  second run silently re-breaks the data. It cannot self-detect completion (a corrected `false`
  and a never-touched-but-correct `false` are identical), so it needs an external marker.
- **Marker** — a meta key `media_is_public_backfill_v1` on the first site
  (`Site.reorder(id: :asc).first`, Camaleon's conventional global-settings holder). The flip and
  the marker write share one `ActiveRecord::Base.transaction`, so they commit together or not at
  all: an interrupted run leaves no marker and re-runs safely; a completed run is a no-op. The
  marker is read straight off the `metas` relation (`.where(key:).exists?`), bypassing the
  meta-value cache so a rolled-back run in a shared cache store can never poison the guard.
- **`v1` suffix** — reserves room for a future, differently-keyed data correction without
  colliding with this one.

### NULL handling

`is_public: NULL` is only reachable for rows written before PR #1285 added
`validates :is_public, inclusion: { in: [true, false] }`. `NOT NULL` evaluates to `NULL` on
Postgres, MySQL and SQLite, so a blanket `update_all('is_public = NOT is_public')` already leaves
those rows alone. A NULL row is invisible to both collections and is a distinct orphaning problem
(out of scope here); the back-fill neither fixes nor worsens it.

## Deploy ordering (operator-facing)

1. Deploy the code (ternary fix).
2. Immediately run `bundle exec rake camaleon_cms:backfill_media_is_public`.

Between (1) and (2) the media browser mislabels existing files (private files list as public and
vice versa). This is a **listing** artifact only: file serving and authorization read the uploader
mode and storage path, never `is_public`, so nothing becomes readable that was not before. The
window is closed by running the task. This ordering is the reason the change ships as its own
reviewed unit with maintainer sign-off rather than as a drive-by one-liner.

## Ecosystem note

`is_public` and the two associations are public surface; an external plugin or theme could read
them. Any such consumer today receives inverted answers, so it is either relying on the bug or
already working around it. Fixing the semantics is correct; the CHANGELOG calls it out so
downstream authors can drop any compensating inversion.
