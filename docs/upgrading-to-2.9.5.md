# Upgrading to 2.9.5

Version `2.9.5` is a bug-fix and security release. It corrects the long-standing inversion of the
media `is_public` flag (with a repair task for existing installs and hardening around stale media
caches), contains media folder deletion to the media root, lets sites carrying taxonomy rows from
a removed plugin be deleted again, makes the bundled JSON configs load under json gem 3, and raises
the bundled `cama_contact_form` floor to `~> 0.1.15`, which includes the release that completes its
security series.

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
| Hit `NameError: undefined local variable or method custom_field_groups` deleting a site or taxonomy row | Nothing — retry the delete after upgrading ([details](#deleting-legacy-taxonomy-rows-no-longer-crashes)) |
| Uses the **contact form** | The same bundle update raises `cama_contact_form` to `~> 0.1.15` |
| Keeps comments in `config/system.json` or in a theme or plugin config you maintain | Remove them before your bundle resolves json gem 3 ([details](#json-configs-must-be-plain-json)) |
| Has colorpicker custom fields that ever held free text | Review affected records — sibling field values may have been blanked ([details](#audit-custom-field-values-after-a-colorpicker-crash)) |

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

## Deleting legacy taxonomy rows no longer crashes

A `term_taxonomy` row whose `taxonomy` value matches no model — typically left behind by a plugin
that was removed or that renamed its taxonomy, such as `ecommerce_coupon` — loads as the base
`CamaleonCms::TermTaxonomy` by design. Destroying one raised `NameError: undefined local variable
or method custom_field_groups` (the identifier's quoting in the message varies by Ruby version),
which also aborted **`Site#destroy`** for any site owning such a row: the site could not be
deleted at all. Both now complete normally. No operator action, and
nothing to repair — simply retry the delete. Rows that map to a real model are unaffected.

---

## Pick up the dependency fix

```bash
bundle update camaleon_cms
```

This raises the bundled `cama_contact_form` floor to `~> 0.1.15`. That covers 0.1.14, the release
completing its contact-form security series (output escaping, auto-reply recipient validation, a
submission throttle, an attachment-count cap, upload-scan coverage, an e-mail tracking-pixel block,
and response-file-cleanup confinement), and 0.1.15, whose plugin config now parses under json gem 3.
Drop-in; no config or API change.

---

## Audit custom-field values after a colorpicker crash

A colorpicker custom field accepts free text, and a saved non-colour value (for example a bare
number) crashed the admin edit form's field rendering on 2.9.4 and earlier. The damage was wider
than the broken picker: the crash aborted the rendering of every custom field registered after it,
and **saving the record in that state silently blanked those unrendered fields' stored values**
(the save replaces all of a record's field values with what the form posts, and the broken form
posted empties).

**Action:** if any of your colorpicker custom fields ever held a non-colour value, review records
of that post type that were edited and saved while on an affected version — their *other*
custom-field values may have been emptied and need re-entering. Rendering now survives bad values,
and a picker that is opened but not used no longer rewrites the field on close.

Separately, the per-kind field options in the custom-fields settings — colorpicker **Color
Format**, the date field's date-vs-datetime toggle, image **versions**, file **formats**, and the
posts field's post-type filter — were silently discarded on every save. They persist now, but any
choice made before this release was never stored: reopen the field group and pick them again.

---

## JSON configs must be plain JSON

The json gem 3.0 no longer accepts comments in JSON by default. Camaleon parses `config/system.json`
and every plugin and theme config with `JSON.parse` at boot, so a file with a `//` or `/* */`
comment raises `JSON::ParserError` and the app does not start. The configs bundled with the gem,
its generator templates and `cama_contact_form` 0.1.15 are now plain JSON.

**Action, before your bundle resolves json 3.x:** remove the comments from your app's
`config/system.json` (`rails generate camaleon_cms:install` wrote them on every earlier version),
and from the configs of any theme or plugin you maintain. Each setting is described in
[Configuration settings](installation.md#configuration-settings).

json 3.x is not usable with this release yet, for reasons outside Camaleon: the bundled
`cama_meta_tag` 1.7.2 still ships a commented config, and under json 3 `ActiveSupport::JSON.decode`
(session cookies, JSON request params) raises on Rails 8.1.3.1 and the 7.1/7.2 series (fixed in
[rails/rails#58601](https://github.com/rails/rails/pull/58601), not in a release as of 8.1.3.1).
Until both are fixed, keep `gem "json", "< 3"` in your Gemfile if your bundle would otherwise
resolve 3.x.

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

### Configs must be plain JSON

A comment in `config/config.json`, `config/camaleon_plugin.json` or `config/camaleon_theme.json`
stops every host app that installs your gem from booting under json gem 3. Remove the comments and
release ([details](#json-configs-must-be-plain-json)).

---

## Recommended rollout

1. `bundle update camaleon_cms` and deploy.
2. Immediately run `bundle exec rake camaleon_cms:repair_media_visibility` (safe to re-run).
3. If you maintain a theme or plugin reading the media associations or flag directly, drop any
   compensating inversion.
