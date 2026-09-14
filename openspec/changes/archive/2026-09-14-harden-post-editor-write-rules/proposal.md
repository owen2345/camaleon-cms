## Why

A max-effort review of the post editor's write rules (PR #1297, this branch) found that the new checks can be bypassed or fail on paths the rules describe as covered, and that the same save still stores one content meta unscanned. Verified through the real endpoints and on MySQL 8:

- **Key folding does not match MySQL.** The check folds a submitted key to lower case, but MySQL's default collations are accent- and compatibility-insensitive, so `meta[témplate]` passes the offered-list and reserved-key checks and the store's `where(key:)` then updates the `template` row; `meta[＿default]` (fullwidth low line) replaces the options hash the same way.
- **A status variant publishes.** `post[status]=Published` (or `published `) is stored verbatim for a user without the publish permission; on MySQL the SQL `published` scopes match it, so the post is listed publicly. A present-but-empty `post[status]=` on update writes `''` to the column, although the code's comment says a blank status is left alone.
- **`meta[summary]` is content the scan never sees.** The save stores it from any user, and the engine's default theme renders the excerpt through `raw`, so an editor without the unfiltered-content permission stores a script that runs on listing and search pages.
- **The refused-save path misfires.** The check runs after the `create_post`/`update_post` hooks (a hook that writes to the persisted post commits before the refusal), and a refused update re-renders through `edit`, whose authorization re-runs against the post with the submitted status assigned, so a user whose right rests on `edit_publish && published?` is sent to the dashboard as unauthorized instead of seeing the refusal.
- **The offered-list check misreads two option shapes.** A hook entry in the `[text, value, {html attributes}]` or `[value, {attributes}]` form the editor's select supports is offered in the form but refused on save, and a pre-rendered option string makes every non-admin save raise. On post type create the check runs with no post type, so a hook that reads it raises or offers a different list than the form did.
- **Corrupt options rows and malformed containers are handled in one place each.** A non-Hash `_default` row is tolerated only by `restore`; `trash`, the edit page and the public page still raise on it. A non-hash `meta`/`options` container is refused only on the post save; the category, tag, site and theme saves still raise or write it pair by pair.
- **Smaller gaps.** The English fallback of `cama_t` drops `scope:`, `separator:` and `raise:`; values stored before the upgrade keep breaking pages while the upgrade note says no operator action is needed and the scan task does not list them; the create action never destroys the new-post draft buffer it tries to (the parameter it reads is never permitted); and the draft-save JavaScript change has no spec.

## What Changes

- **Meta and option key names** in a post save or draft save must be ASCII words (`A-Z a-z 0-9 _ - .`); any other key is refused for every user, with an error naming it, since no folding reproduces MySQL's collations.
- **A submitted `post[status]`** must be one of the statuses the editor offers (`published`, `pending`, `draft`); anything else is refused. A blank or absent status on update leaves the current status alone; on create it takes the column default and then the publish rule.
- **`meta[summary]`** is held to the same scan as post content for a user without the unfiltered-content permission: a value the scan refuses is a refusal of the whole save, naming the field. Administrators and permission holders are unaffected.
- **The request check runs before the create/update hooks**, and a refused update re-renders the form without re-authorizing the mutated post.
- **The offered-list check derives an option's value the way the editor's select does**, so every entry shape Rails offers is accepted; a pre-rendered option string offers nothing but blank instead of raising. The post type create check runs with the post type being created.
- **A non-Hash options row reads as empty** for every reader and writer, so `trash`, the edit page and the public page work on it (a later engine write replaces it); `restore`'s one-off guard goes away.
- **`set_metas` and `set_options` refuse a container that is not a set of fields** with an error, and the admin controllers turn that error into a flash message on the submitted save instead of a 500 or a pair-by-pair write.
- **`cama_t`** keeps `scope:`, `separator:`, `raise:` and `throw:` for its English fallback lookup and no longer mutates the caller's options.
- **`camaleon_cms:security:scan_content`** also lists posts whose stored template, layout or default template/layout is not a file of the site's theme, posts and post types whose options row is not a JSON object, and post summaries the content scan would refuse. The upgrade note points operators at it.
- **Creating a post from a new-post draft** destroys the current user's own parentless draft buffer named by the form, as the code intended.
- **Tidy-ups with no behavior change:** the refusal scan walks each param group once; the view-choice fields, their messages and the status vocabulary live in one place each; the write-integrity specs share one context; a stale spec title and a weak assertion are fixed; the draft-save JavaScript gets a feature spec.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `post-editor-write-integrity`: the reserved-key requirement gains the key-name rule; the template/layout requirement gains the option-shape and post-type-create behavior; the restore/publish requirement gains the submitted-status rule and the blank-status-on-update behavior; new requirements cover the refused-save path (before hooks, no re-authorization), the new-post draft buffer, and the scan task's listing.
- `meta-storage-integrity`: a non-Hash options row reads as empty; `set_metas`/`set_options` refuse a container that is not a set of fields.
- `post-decorator-class-integrity`: a post type whose options row is not a JSON object decorates with the default without a lookup failure (the row reads as no options).
- `post-content-sanitization`: the summary meta is held to the content scan when a user without the permission saves it.
- `generated-markup-escaping`: the status-column requirement's rationale names the writers that still bypass validation now that a submitted status is held to the editor's set; the scenario is retitled to what it exercises.
- `frontend-controller-helper-compatibility`: `cama_t`'s English fallback honors the lookup options the caller passes.

## Impact

- **Code:** `app/controllers/camaleon_cms/admin/posts_controller.rb`, `posts/drafts_controller.rb`, `settings/post_types_controller.rb`, `concerns/camaleon_cms/admin/post_view_choices_concern.rb`, `admin_controller.rb`, `app/models/concerns/camaleon_cms/metas.rb`, `app/models/camaleon_cms/post.rb` (status and engine-key vocabulary), `app/helpers/camaleon_cms/camaleon_helper.rb`, `lib/tasks/unsafe_stored_content.rake`, `config/locales/camaleon_cms/admin/en.yml`.
- **Ecosystem:** `set_metas`/`set_options` now raise on a non-hash container; every surveyed caller passes a hash or request params. A plugin form field whose meta key is not an ASCII word would now be refused; none surveyed uses one. `cama_t` regains the fallback semantics 2.9.4 had for `scope:`/`raise:` callers.
- **Docs:** `docs/security/permissions.md`, `docs/ai/ecosystem.md`, `docs/upgrading-to-2.9.5.md`, `CHANGELOG.md`, and the archived `restrict-post-template-layout-and-reserved-metas` design/tasks records, which contradict the shipped code.
- **In-flight work:** PR #1302 rewrites `Metas#options`; the non-Hash normalization lands on the same lines and is merged with it.
