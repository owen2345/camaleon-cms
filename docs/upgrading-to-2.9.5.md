# Upgrading to 2.9.5

Version `2.9.5` is a bug-fix and security release. It corrects the long-standing inversion of the
media `is_public` flag (with a repair task for existing installs and hardening around stale media
caches), contains media folder deletion to the media root, and raises the bundled
`cama_contact_form` floor to the release that completes its security series.

**Your stored files are never touched by upgrading.** One change in this release does rewrite
database rows: the media *cache* table (which mirrors your storage) is purged and rebuilt by the
repair task below — the files themselves, their locations, and their access control are unchanged.
Each change is described in full in [CHANGELOG.md](../CHANGELOG.md), where **breaking changes**
are flagged per entry; this guide is the upgrader runbook — what to do, what you may observe, and
what theme/plugin developers should know.

## At a glance — what applies to you

| If your install… | Do this |
| --- | --- |
| **Any install** | `bundle update camaleon_cms`, deploy, then **immediately** run the [media visibility repair](#media-visibility-repair) |
| Reads `site.public_media` / `site.private_media` or `media.is_public` **directly** (reports, plugins, exports) | Those now return what their names say — drop any compensating inversion ([details](#notes-for-theme--plugin-developers)) |
| Uses the **contact form** | The same bundle update raises `cama_contact_form` to `~> 0.1.14` |

---

## Media visibility repair

Media rows stored `is_public` as the *opposite* of each file's real visibility, ever since the
media cache table was introduced (2018): `site.public_media` returned the site's private files and
vice versa. The media browser and file serving were unaffected — they key off the upload mode and
storage path, never the stored flag — but any direct reader of the flag or the associations got
inverted answers. Uploads now store the flag matching real visibility.

**Action required (one step, right after deploying):**

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:repair_media_visibility
```

What it does: the media table is a pure cache of your storage, so the task purges the cached rows
(in batches) and rebuilds them through the corrected code, deriving every flag from where each
file actually lives. Local sites get their public cache rebuilt eagerly by the task; private
caches and cloud-storage (AWS) sites rebuild automatically on their next media browse. The task
is **convergent — safe to run again at any time**, including on an already-correct database, and
it also cleans up stale, duplicate, or orphaned cache rows from before the upgrade.

**Run it before further media activity.** Until it runs, pre-upgrade cache rows sit in the
opposite collection from where the corrected code looks, so the media browser can mislist
existing entries, and the first browse may trigger a full storage re-scan (a slow request that
also duplicates rows). None of this damages your files — uploads that collide with an uncached
name are renamed (`file_1.ext`), deletes tolerate a missing cache row, and the repair task heals
any cache rows disturbed in the window — but the clean sequence is: deploy, run the task, resume
normal use. Expect the task to take roughly as long as a first browse of your media library
(it walks local storage and reads image dimensions).

**Also in this change** (each active immediately after deploy):

- Upload name-collision checks now consult storage as well as the cache: a file present on disk
  or S3 without a cache row gets a `_1` rename instead of being silently overwritten.
- Deleting a file or folder whose cache row is missing no longer errors after removing the file.
- Browsing an unknown media folder (stale bookmark, cleared cache) renders an empty listing
  instead of an error page.
- The admin media **clear cache** action now purges both the public and the private cache, and
  each rebuilds on its next browse.

---

## Media folder deletion is contained to the media root

A media folder-delete whose key resolved to the media root (e.g. `/.`) let a user with the media
permission delete the site's **entire upload directory** from disk. Deletion is now contained to
the media root; folders whose stored name or path collapses (e.g. one named `.`) no longer crash
with `SystemStackError` or delete sibling media on destroy, and such non-canonical names and
paths are refused at save. No operator action; you may observe the save-time refusal if something
was creating such folders programmatically.

---

## Pick up the dependency fix

```bash
bundle update camaleon_cms
```

This raises the bundled `cama_contact_form` floor to `~> 0.1.14`, the release completing its
contact-form security series (output escaping, auto-reply recipient validation, a submission
throttle, an attachment-count cap, upload-scan coverage, an e-mail tracking-pixel block, and
response-file-cleanup confinement). Drop-in; no config or API change.

---

## Notes for theme & plugin developers

### `public_media` / `private_media` / `is_public` now mean what they say

If your code reads `site.public_media`, `site.private_media`, or `media.is_public` directly, it
was receiving inverted answers on every install since 2018. If you compensated (swapped the
associations, negated the flag), **drop the compensation** — after the repair task runs, the
stored flag matches real visibility. If you read them uncompensated, your feature starts
returning the right rows.

### Uploader behavior changes

- `search_new_key` (and therefore `add_file` without `same_name: true`) now treats a file present
  in storage as a name collision even when no cache row exists, so uploads are renamed rather
  than overwriting. Pass `same_name: true` where replacing in place is intended — unchanged from
  before.
- `objects(prefix)` returns an empty relation instead of `nil` for an unknown folder key; code
  that branched on `nil` should branch on `.empty?`.
- `clear_cache` purges both visibility collections for the site, not just the current mode's.

---

## Recommended rollout

1. `bundle update camaleon_cms` and deploy.
2. Immediately run `bundle exec rake camaleon_cms:repair_media_visibility` (safe to re-run).
3. If you maintain a theme or plugin reading the media associations or flag directly, drop any
   compensating inversion.
