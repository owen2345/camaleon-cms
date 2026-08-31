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
- **Flip the scopes only:** the stored values would come out right, but `site.public_media` would
  return private files — the exact consumer-facing bug, relocated. ❌
- **Flip the ternary AND the scopes:** the two inversions cancel; back to inverted data. ❌

So: **ternary flips, scopes and `Media` stay untouched.**

## Repairing existing rows: purge-and-rebuild, not a flip

Every column on a media row (`name`, `folder_path`, `is_public`, `is_folder`, `file_size`,
`file_type`, `dimension`, `url`, `thumb`) is derived from storage by the uploaders'
`browser_files`/`file_parse`; nothing on the row is user-authored. The media table is a
**rebuildable cache**, and the codebase already treats it as one (`clear_cache` destroys rows and
the next browse rebuilds them). The repair therefore does not transform rows in place — the
`camaleon_cms:repair_media_visibility` rake task purges cached rows (in batches, so no
table-length transaction) and lets the cache rebuild from storage through the corrected routing,
which derives each flag from where the file actually lives. Local sites rebuild their public
collection eagerly in the task; private collections and cloud-storage (AWS) sites rebuild lazily
on their next media browse.

An in-place inversion (`is_public = NOT is_public` behind a run-once marker) was considered and
rejected — it fails four independent ways:

1. **It corrupts rows that are already correct.** A blind flip cannot distinguish pre-fix rows
   from rows written correctly after the fix deploys (uploads in the deploy window) or rows
   written directly through the visibility associations by plugins/imports, which never passed
   through the inverted router. No timestamp cutoff can recover writer provenance.
2. **Raw SQL inversion is unsafe on legacy data.** Rails wrote SQLite booleans as `'t'`/`'f'`
   before 6.0; SQLite coerces both strings to 0, so `NOT is_public` turns both into 1 — mangling,
   not inverting.
3. **A self-inverse operation makes every guard failure destructive.** A run-once marker is
   check-then-act (concurrent runs double-flip), lives on a deletable row (the first site's metas
   are `dependent: :destroy`), and never arms on an empty database — each failure re-runs the
   flip over correct data. Purge-and-rebuild is **convergent**: re-running it, concurrently or on
   an already-correct database, reproduces the same correct state, so it needs no guard at all.
4. **A flip preserves garbage.** Duplicate or phantom rows (e.g. minted by a deploy-window
   re-scan) survive an UPDATE; the purge removes them and the rebuild recreates only what storage
   actually holds.

`is_public: NULL` rows (pre-validation legacy data) are simply purged with everything else and
recreated validly by the rebuild — the orphaning concern disappears rather than being deferred.

## Deploy ordering and the window (operator-facing)

1. Deploy the code (ternary fix plus the stale-cache hardening below).
2. Immediately run `bundle exec rake camaleon_cms:repair_media_visibility`, before further media
   activity.

Between (1) and (2), pre-fix rows sit in the opposite collection from where the corrected code
looks. This window is **not** cosmetic: browsing can trigger a re-scan that duplicates rows,
same-named uploads could overwrite stored files, and deletes could crash or miss their row. The
change hardens each of those paths independently of the task — upload collision checks now
consult storage, not just the cache; deletes tolerate a missing cache row; an unknown folder
renders an empty listing; the admin clear-cache purges both visibility collections — and the
repair task itself heals any rows damaged during the window, because it rebuilds from storage
rather than trusting what the window wrote. The instruction to run the task immediately stands:
hardening narrows the window's blast radius, the task closes it.

## Ecosystem note

`is_public` and the two associations are public surface; an external plugin or theme could read
them. Any such consumer today receives inverted answers, so it is either relying on the bug or
already working around it. Fixing the semantics is correct; the PR description calls the
corrected semantics out so downstream authors can drop any compensating inversion.
