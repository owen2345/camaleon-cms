# Upgrading to 2.9.5

Version `2.9.5` is a bug-fix and security release. It corrects the long-standing inversion of the
media `is_public` flag (with a repair task for existing installs and hardening around stale media
caches), contains media folder deletion to the media root, lets sites carrying taxonomy rows from
a removed plugin be deleted again, and raises the bundled `cama_contact_form` floor to the release
that completes its security series.

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
| Has plugins or themes that submit post template or layout values, non-ASCII meta keys or a status other than published/pending/draft, or relies on a non-publisher reaching `published` | Offer templates through the hooks; a user without the publish permission now stays at `pending` on create, update and restore; run the scan task for stored values ([details](#post-templates-reserved-keys-and-restore)) |
| Has colorpicker custom fields that ever held free text | Review affected records — sibling field values may have been blanked ([details](#audit-custom-field-values-after-a-colorpicker-crash)) |
| Sets `cama_post_decorator_class` on a post type (a plugin or theme decorator) | It must name a `CamaleonCms::PostDecorator` subclass; the scan task lists stored values that are now ignored ([details](#cama_post_decorator_class-must-name-a-post-decorator)) |
| Runs a plugin or theme whose manifest names a hook handler its helpers don't define | That hook now raises `NoMethodError` on controllers too — define the handler or drop the entry; camaleon-ecommerce's **Upgrade** button is one such case ([details](#hook-handlers-run-once-per-dispatch)) |
| Has a plugin or theme that reads a saved record's `data_options`/`data_metas` back, or overrides `save_metas_options_skip` | They read `nil` once written and the hook is gone — read `options`/`get_meta` instead ([details](#data_options-and-data_metas-are-written-once)) |
| Sets `$current_site` anywhere: an initializer, a console script, a rake task | It is no longer read. On a server, map your domains to your sites; elsewhere, pass the site to `current_site(site)` ([details](#the-current_site-global-is-no-longer-read)) |
| Calls `reset_ability`, assigns `PostDefault.current_user`/`current_site`, compares a boolean meta to `'t'`/`'f'`, or reads a record after `reload` or on a `dup` copy | `reload` rebuilds the ability and drops memoized reads; a boolean meta reads as the boolean whenever it was stored ([details](#reload-and-dup-drop-a-records-memoized-state)) |
| Has plugin or theme code that changes a `get_meta` default in place and reads the meta again without `set_meta`, reads back the object it passed to `set_meta` on the same instance, or passes a numeric meta it just wrote to a String method | Write changes with `set_meta`, and call `.to_s` before a String method; a read returns what a reloaded record reads ([details](#get_meta-and-set_meta-read-as-a-freshly-loaded-record)) |
| Has plugin or theme code that calls `window.save_draft` / `App_post.save_draft_ajax` and reads the draft right after the call | The save is asynchronous now: read it in the callback ([details](#the-post-editors-draft-save-is-asynchronous)) |

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

- **`cama_contact_form` `~> 0.1.15`** covers 0.1.14, the release completing its contact-form security
  series (output escaping, auto-reply recipient validation, a submission throttle, an
  attachment-count cap, upload-scan coverage, an e-mail tracking-pixel block, and
  response-file-cleanup confinement). Drop-in; no config or API change.
- **`cama_meta_tag` `>= 1.7.3`** saves only its six SEO options from the category and post type
  forms. A theme or plugin that adds its own `options[...]` inputs to those forms must save them from
  its own hooks.
- **json stays below 3.** Every released Rails fails under json gem 3 in ActiveSupport's JSON
  encoding or decoding, so camaleon_cms requires json `< 3`. The update moves a bundle that already
  resolved json 3 back to 2.x; a gem that requires json 3 cannot be bundled with this release.

---

## Post templates, reserved keys and restore

The admin post save and its draft autosave stored every `meta[...]` and `options[...]` key a request
carried. A non-admin could point a post at any view the template lookup finds, and an admin view
broke that post's public page. Anyone could replace the post's whole options hash with `meta[_default]`.
A contributor without the publish permission could store `options[status_default]=published` and
restore the post to publish it.

- A non-admin's template or layout value must be blank or one the post editor offers. An
  administrator's is stored as written. The same offered-list rule applies to a post type's
  `default_template`/`default_layout` for a non-admin, since a post falls back to it.
- Keys the engine maintains itself are refused from any request: `_`-prefixed metas, `visits`,
  `comments_count`, `status_default` and `draft_status`. A meta or option key must be an ASCII word
  (letters, digits, `_`, `-` and `.`), since MySQL's collations fold accented and fullwidth spellings
  onto those keys. A `meta`, `options` or `field_options` value that is not a set of fields (an array
  of pairs) is refused too, and the category, tag, site and theme saves now answer such a value with
  an error message instead of a server error.
- A submitted post status must be exactly `published`, `pending` or `draft`; any other spelling is
  refused. A blank status on an update leaves the post's current status alone.
- The post summary is content: for a user without the unfiltered-content permission it is held to the
  same scan as the body, since themes render the excerpt unescaped.
- A user without the publish permission can no longer reach `published` on any path: not by omitting
  the status on create (the column default), not on a blank-status draft update, and not through
  `restore`. `restore` acts only on trashed posts and returns a post to the status it had when that is
  a status a post may be restored to (`published` only for a publisher; a `draft_child` autosave buffer
  comes back as a buffer, not a standalone post).
- A refused save is decided before the `create_post`/`update_post` hooks run, and a refused update
  shows its refusal on the form rather than an authorization error for a role whose right rests on
  the post being published. A post with an unreadable options row no longer breaks its pages.
- Creating a post from an autosaved new-post draft now removes that draft buffer.

Either refusal names the field and saves nothing. Values stored before the upgrade are left as they
are, and a template or layout pointing at an admin view keeps breaking that post's public page until
it is cleared by hand: run `bundle exec rake camaleon_cms:security:scan_content` (read-only), which
now also lists posts and post types whose template, layout or default view is not a view of the site's
theme (a plugin hook may still offer it), options rows that are not JSON objects, and post summaries
the content scan would refuse.

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

## The `$current_site` global is no longer read

`current_site` resolved the `$current_site` global ahead of everything but an explicit argument, and
when no site matched a request the error log advised setting it to `CamaleonCms::Site.first.decorate`.
A server that followed that advice served every request of a process from that one site record, and a
record keeps the options and metas it has read in memory. The process then never saw site settings
saved by another worker, a console or a job, it kept serving cached pages that other workers'
`front_cache` invalidations retired, and its threads updated one shared options hash. The global is
gone from the resolution order, and the log points to domain mapping instead.

**Action:** search your app for `$current_site`. On a server, remove the assignment and map your
domains to your sites ([how](https://camaleon.website/documentation/category/139779-examples/how.html)).
In a console, a script or a rake task, pass the site instead; later `current_site` calls in that
process return it:

```ruby
include CamaleonCms::SiteHelper
current_site(CamaleonCms::Site.find(id))
```

The `camaleon_cms:generate_thumbnails` task, which set the global, is removed: it iterated a `fog`
connection the uploader no longer opens, so it raised before reaching a file.

---

## Notes for theme & plugin developers

### `public_media` / `private_media` / `is_public` now mean what they say

If your code reads `site.public_media`, `site.private_media`, or `media.is_public` directly, it
was receiving inverted answers on every install since 2018. If you compensated (swapped the
associations, negated the flag), **drop the compensation** — after the repair task runs, the
stored flag matches real visibility. If you read them uncompensated, your feature starts
returning the right rows.

### `cama_post_decorator_class` must name a post decorator

A post type's decorator class option is loaded as code, so a write that sets or changes it now has
to name a subclass of `CamaleonCms::PostDecorator`: any other value is refused at save with an
error naming the option, whoever writes it. A value already stored that fails the check (written
before this release, left behind by a removed plugin, or imported) is ignored instead: the posts
decorate with the default, a warning is logged once per request, and saving the post type's other
options keeps working. A decorator inheriting from `CamaleonCms::PostDecorator`, as
camaleon-ecommerce's does, is unaffected. `bundle exec rake camaleon_cms:security:scan_content`
lists the post types whose stored value is ignored.

### Hook handlers run once per dispatch

A handler registered for a hook now runs exactly once when the hook fires, and an error it raises
reaches the code that fired the hook; the dispatcher no longer rescues the failure, reloads the
plugin's helpers and runs the handler again, so a handler that fails after a side effect no longer
repeats it. The plugin's helper modules are included before its handlers run, so a handler one of
them defines is called even where the controller or view already has a method of that name.

A handler that none of the plugin's helper modules defines now raises `NoMethodError` when its hook
fires from a controller, as it always has in views and as it did on controllers through 2.9.2; 2.9.3
and 2.9.4 skipped it there silently. A hook that gates content, such as `filter_post` or
`post_can_visit`, therefore fails instead of serving what its missing handler would have held back.
If a plugin or theme manifest (`config.json`, `camaleon_plugin.json`) names a handler its helpers
do not define, define the method or remove the entry. camaleon-ecommerce's manifest names an
undefined `ecommerce_on_upgrade`, so its **Upgrade** button in the plugins list raises until that
entry goes; the plugin itself keeps working.

### Uploader behavior changes

- `search_new_key` (and therefore `add_file` without `same_name: true`) now treats a file present
  in storage as a name collision even when no cache row exists, so uploads are renamed rather
  than overwriting. Pass `same_name: true` where replacing in place is intended — unchanged from
  before.
- `objects(prefix)` returns an empty relation instead of `nil` for an unknown folder key; code
  that branched on `nil` should branch on `.empty?`.
- `clear_cache` purges both visibility collections for the site, not just the current mode's.

### Post template and layout values

A plugin or theme that submits its own post template or layout name must offer it through the
`post_get_list_templates` or `post_get_list_layouts` hook, or a non-admin's save is refused
([details](#post-templates-reserved-keys-and-restore)); a handler may add any shape Rails' `select`
renders, and on post type create it receives the post type under creation. Every other
`meta[...]`/`options[...]` field is still stored as submitted, as long as its key is an ASCII word.
`set_metas`/`set_options` now raise `CamaleonCms::Metas::InvalidContainer` for a container that is not
a Hash or request parameters (blank stays a no-op); `cama_t` honors `scope:`/`raise:` in its English
fallback again.

### `data_options` and `data_metas` are written once

A record's `data_options` and `data_metas` are written by the first save that completes and then read
`nil`, so a later save of the same instance no longer writes them again over options or metas set
since; a copy taken with `dup` after that save carries none of them. A save rolled back after writing
them (a later callback raising, an enclosing transaction rolled back) queues them again for the next
save of the instance; a record whose creation was rolled back also stores the metas set before that
save when it is saved again, and a record that already existed drops the metas that save wrote,
reading them again on demand, in the options hash or list it handed out too, and stores with its next
save a meta you built on it and had not saved yet. A `created_post_type` or `updated_post_type` handler that read the submitted
options from `args[:post_type].data_options` now gets `nil`: read the stored ones with `options` or
`get_option`.

A post type's `data_metas` are stored at creation rather than on its first update; its default options
fill in under the options set on the record before its first save and under the ones given. A
`_default` meta given in `data_metas`, the options row itself, merges with `data_options` instead of
replacing them, on every record, and a `cama_post_decorator_class` value in it is validated like one
given in `data_options`. A `data_options` or `data_metas` value that is not a Hash or request
parameters raises `CamaleonCms::Metas::InvalidContainer` before the row is written. The
`save_metas_options_skip` and `fix_save_metas_options_no_changed` methods of `CamaleonCms::Metas` are
removed: the concern's `after_create` and `before_update` write the queues through `save_metas_options`
with no hook in between, and no surveyed plugin or theme overrides either.

### `reload` and `dup` drop a record's memoized state

A record memoizes its `get_meta` and `get_option` reads, and the values plugins memoize through
`cama_fetch_cache`, for the request. `reload` now drops them once it has replaced the record's state,
so reads after it return what is stored, and it rebuilds the record's ability and a user's role; a
reload that fails leaves everything as it was. `cama_clear_cache` drops them on demand. A copy made
with `dup` starts with no memoized values, no record of the original's last queued write and its own
`data_options`/`data_metas`, so a rollback of the original's transaction no longer queues the
original's values on the copy. `Site#get_languages` follows the `languages_site` meta like any other
read. `CamaleonRecord#reset_ability` is removed: call `reload` where a spec or a plugin used it. The
`CamaleonCms::PostDefault.current_user` and `current_site` class attributes are removed too: they held
one value for every request of the process and hid the per-request user and site every other record
reads, so a post's own `can?` answered `false` outside a request; a post now reads `CurrentRequest`
like every record, and code that assigned them assigns `CurrentRequest.user`/`CurrentRequest.site`.

Two read forms change. A boolean written with `set_meta` reads back as the boolean; earlier releases
stored the text column's `t`/`f`, which every read returned as a String, so a `false` flag read as set
once loaded again. A row stored that way is read as the boolean and stored again as `true`/`false` on
its first read (a read where writes are prevented, on a replica for instance, leaves the row for a
later one), so nothing needs rewriting; a plugin that compared such a read to `'t'` or `'f'` compares
to the boolean now. The hashes inside a stored array now read by Symbol or String key, as a stored hash
always did.

### Options read by either key type on the instance that wrote them

- After `set_meta` writes a record's options as a plain Hash, request parameters or a JSON string,
  `options` on that same object returns an indifferent copy, so `options[:key]` and `get_option` find a
  String or a Symbol key alike, as a freshly loaded record already did, and a nested option is a hash, not
  an `ActionController::Parameters` object. The copy carries no default your hash may have. An option
  written on that object afterwards is stored beside the options you passed. A post type created with a
  `_default` meta in `data_metas` keeps the options that meta holds under its defaults, whichever key type
  names them. `get_meta` on that object returns that same indifferent copy, never the hash you passed, and
  the option writers store and return their own hash instead of writing into yours as 2.9.4 did; a change
  made to the hash `options` returns, or to a hash nested in it, without an option writer, no longer
  reaches it.
- Options that are nil, an empty string or absent read as empty options: `options` returns a new empty
  hash on each read instead of `nil` or `''`, `get_option` and the option writers no longer raise, and a
  change made to that empty hash without an option writer is neither read back nor stored. Code that
  branched on `options.nil?` should branch on `.empty?`.

### `get_meta` and `set_meta` read as a freshly loaded record

On the object that reads or writes a meta, 2.9.4 could return something a freshly loaded record would not:
the default an earlier read had passed, or the very object you gave `set_meta`. Every read on that object
now returns what a freshly loaded record reads.

- A read of a meta with no value — no row, or a stored null or empty string — returns the default passed to
  that call. Before, a record memoized the default of its first read of that meta, so later reads on the
  same object got that default, with any in-place change you made to it, and a meta stored as null read as
  nil whatever the default. `get_option` returns its default for an option stored as null, as it already
  did for an empty string, and `set_meta(key, nil)` or `set_meta(key, '')` reads back as the default.
- A value written with `set_meta` reads back as `set_meta` stores it: a Hash or request parameters as an
  indifferent hash (`[:key]` and `['key']` alike), a JSON string as the value it holds, a numeric or
  boolean String as the number or the boolean, and any other String as a plain String in UTF-8, so a view
  escapes an `html_safe` String you wrote. A one-letter `'t'` or `'f'`, a String or a Symbol, is stored as its JSON
  string (`"f"`) and reads back as that String, since a row holding the bare letter reads as the boolean an
  earlier release stored that way. A value of another class reads back as a reload reads the text it is stored as: a `BigDecimal`
  as a Float, and a `Time` or a `Date` as its String. Your own object is left as passed and never handed
  back by a read (`set_meta` still returns it), so a change made to it after the write is not read; code
  that compared a read to its own hash, or iterated its Symbol keys, on the writing object sees the stored
  form now, as it already did once the record was loaded again. Code that passes such a read to a String
  method, like a tracking number of digits to `gsub`, calls `.to_s` on it first, as a loaded record already
  required.
- A meta with a stored value is memoized on the object and handed back as that one value: a change made to
  it in place shows in later reads on that object, and in `options` for the `_default` row, but is not
  stored. Write changes with `set_meta` whether or not a row exists, as the option writers already do. A
  hash or list you read and write back stays the one the object reads, so a hash `options` returned, and a
  hash or list nested in it that a write leaves unchanged, keep reading the option writes made after it, as
  in 2.9.4; if that write is refused or fails, it reads what is
  stored again.
- A meta or option written or deleted directly inside a transaction that is rolled back no longer keeps its
  rolled-back value on the object that wrote it: its next read reads what is stored, and its next save no
  longer stores again a meta the rollback removed.
- `set_meta` raises `ActiveRecord::RecordInvalid` or `ActiveRecord::RecordNotSaved` when a validation or a
  callback you added to `CamaleonCms::Meta` refuses the row it updates or creates, as it raises when the
  database refuses it, instead of returning as if the value were stored and reading it back on the object
  that wrote it. A meta set on a record not saved yet is stored by the record's save, which fails when the
  meta is refused, as before.
- `set_settings` on a post type or a post writes every setting in one options write, through `set_options`,
  instead of one per setting, so it takes what `set_options` takes, a Hash or request parameters, and a
  setting a post type refuses leaves the others unwritten.
- `the_meta` and `the_option` return a meta or option stored as a number, a boolean or a hash as read, where
  they raised on a loaded record. A String still reads through the locale, and so does every item of an
  Array, as a String whatever it holds: `[1, true]` reads as `['1', 'true']`, as it did before.

### The post editor's draft save is asynchronous

`window.save_draft(callback)` (the same function as `App_post.save_draft_ajax`) no longer blocks the
page: it returns at once and runs `callback(response)` when the save succeeds, where it used to run it
before returning. Code that reads the draft id, `#post_draft_id` or the Preview link right after the call
should read them in the callback. A third argument, `on_failure`, runs when the save is refused, the
request fails or could not be sent, including a save that has not returned after `App_post.save_timeout_ms` (30 seconds); a
failed request the caller asked for (not the minute timer's) also shows an error. A call made while a save
is running waits for it, so the draft id it returns is reused. The values `App_post.submit_wait_ms` and
`App_post.save_timeout_ms` are only defaulted when unset, so `0` is kept (no hold, no timeout).
The form is compared by reading its own TinyMCE editors themselves (an editor elsewhere on the page is
neither compared nor sent): a textarea behind an editor is written
only when a draft is sent (and by TinyMCE on blur and submit, as before), no longer by every comparison,
so content a plugin writes into such a textarea stays as written until then.
Submitting the post while a save is running shows the loading overlay and holds the submit until the save
finishes, or for `App_post.submit_wait_ms` (15 seconds) if it has not returned by then; a refused save keeps
the post on the form with the refusal shown, a failed request lets it go. A held submit is stopped before
validation and any other submit listener see it, and dispatched again in full when the hold ends, so each
listener (one a plugin delegates from an ancestor included) and the form's default action run once, then.

---

## Recommended rollout

1. `bundle update camaleon_cms` and deploy.
2. Immediately run `bundle exec rake camaleon_cms:repair_media_visibility` (safe to re-run).
3. If you maintain a theme or plugin reading the media associations or flag directly, drop any
   compensating inversion.
4. Run `bundle exec rake camaleon_cms:security:scan_content` (read-only); it now also lists post
   types whose stored decorator class option is ignored, so you can clear or correct them.
