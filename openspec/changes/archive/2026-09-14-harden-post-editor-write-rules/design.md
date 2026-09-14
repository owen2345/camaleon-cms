## Context

See proposal.md for the findings. The pieces this change touches, as they stand on the branch:

- **The request check** is `PostsController#post_params_refusals`, run at the top of `save_post_with_fields` (after the `create_post`/`update_post` hooks) and at the top of the drafts actions. It reads `params[:meta]`/`params[:options]` as hashes, folds keys with `strip.downcase`, refuses reserved keys for everyone and unoffered template/layout values for non-admins, and the actions re-render through `new`/`edit` on refusal.
- **The offered lists** come from `PostViewChoicesConcern#cama_offered_view_choices`, which reduces each entry with `entry.last`; `Settings::PostTypesController` repeats the field-to-lister map inline and runs its check with `@post_type` nil on create.
- **Statuses** are literals: `get_post_data` permits any `post[status]` string and `publish_or_pending` rewrites only the literal `published`; `RESTORABLE_STATUSES` and the reserved-key lists live in the controller.
- **`Metas#options`** returns whatever `get_meta('_default')` parsed; `get_option` and `writable_options` call Hash methods on it. `set_metas`/`set_options` iterate any container. `AdminController` already rescues `RecordInvalid` from gated saves into a flash and a redirect back.
- **`cama_t`** looks the English fallback up with `I18n.t(key, locale: :en)` and writes `:default` into the caller's hash.
- **The scan task** (`camaleon_cms:security:scan_content`) lists content, custom-field values and post type decorator options; `docs/security/permissions.md` names it as the complement of every save-time gate.
- **MySQL** resolves `where(key:)` under `utf8mb4_general_ci`/`unicode_ci`/`0900_ai_ci`: accents fold on all three, fullwidth forms on the UCA ones, and `0900_ai_ci` is NO PAD (trailing spaces are not ignored). The suite runs on SQLite, whose `=` is byte-wise.

## Goals / Non-Goals

**Goals:**
- Every rule the previous change stated holds on MySQL as on SQLite, with one implementation per rule.
- A refused save writes nothing, whatever hooks are registered, and always shows its refusal.
- Corrupt rows and malformed containers are handled once, where the data is read or written.

**Non-Goals:**
- **Render-side filtering** of a stored template, layout or summary: the maintainer rule keeps stored values served verbatim. History is listed by the scan task, not rewritten.
- **A status allow-list on the model:** `trash`, `restore` and drafts write engine-chosen statuses with `update_column`/`save(validate: false)` and seeds run without a user; the request rule is where the vocabulary is decided.
- **Making `field_options` malformed containers a refusal outside the post save:** `cama_permitted_field_options` serves many controllers with a silent-empty policy; the post save alone adds `field_options` to its container check.

## Decisions

### D1. Reject non-ASCII key names instead of folding further

No Ruby folding reproduces a collation: `transliterate` misses ignorable characters (a soft hyphen inside `template` is equal to `template` under the UCA collations) and NFKC misses `ß`/`ss`. The reserved and offered fields are all ASCII words, so a key that is not `\A[A-Za-z0-9_.-]+\z` after `strip` cannot be a legitimate spelling of one and is refused for every user, as a validity rule on the key name (the same footing as the reserved-key rule). The existing case fold stays for the ASCII keys. Every surveyed plugin and theme field uses ASCII keys.

**Alternative rejected:** comparing in the database with the column's collation. It needs a query per key and cannot be expressed portably; and the fold would still have to be right for the rows that do not exist yet.

### D2. Hold `post[status]` to the editor's set, and keep a blank update status out of the write

Reject, don't transform: a submitted status is accepted only when it is exactly `published`, `pending` or `draft` (`Post::EDITOR_STATUSES`); `Published` is refused, not downcased. The check joins `post_params_refusals`, so it runs before anything is written and answers the same way. On update a blank (absent or empty) status is removed from the attributes before the write, which makes the code's comment true and keeps the draft-promotion branch's assignment from being overwritten; on create a blank status becomes the column default before the publish rule, as before. `draft_child` and `trash` are never submittable: drafts force `draft_child`, and trash has its own action. The vocabulary (`STATUSES`, `EDITOR_STATUSES`, `RESTORABLE_STATUSES`, `ENGINE_META_KEYS`, `ENGINE_OPTION_KEYS`) moves to `CamaleonCms::Post`, next to the predicates and writers it mirrors.

The status output-escaping spec's "stores the submitted status verbatim" example, which documented the open source, becomes a refusal example; its rendering example already plants the payload with `update_column`.

### D3. Scan the summary in the request check with the content gate's detector

`summary` is a meta row, so a `Post` validation cannot see it, and the content gate's trust decision (`trusted_for_unfiltered_html?`) reads the request user through `CurrentRequest`. The request check calls the same detector (`CamaleonCms::UnsafeMarkup` with `Post::CONTENT_ALLOWED_TAGS`/`ATTRIBUTES`, and the size bound) on `params[:meta][:summary]` when `cannot?(:post_content_unfiltered_html, @post_type)`, naming the field with the existing `content_rejected`/`content_too_large` wording. Drafts share the check. Multilingual summaries are scanned as one string, as content is.

**Alternative rejected:** scanning in `Post#set_meta` for `summary`. Server-side writers (imports, themes) would be blocked, against the rule that only request input is gated.

### D4. Decide the refusal before the hooks; re-render without `edit`

`create`/`update` compute the refusals right after `get_post_data` and, on update, after the request's own `authorize!`; with refusals they assign the submitted attributes for display, add the errors and render the form through a private `render_post_form` that carries `edit`'s breadcrumb and `edit_post` hook but not its `authorize!`. `save_post_with_fields` keeps only the transaction. `create` still re-renders through `new`, whose authorization is on the post type and unaffected by the assignment. The drafts actions already check before their hooks.

### D5. Derive option values as Rails does

The concern strips Hash elements from an Array entry before taking its last element (Rails' `option_text_and_value`), recurses into a grouped entry's value list, and treats a String list as offering nothing (Rails renders it verbatim, so its values are unknowable). The concern also owns the field-to-lister maps (`POST_VIEW_LISTERS` for `meta[template]`/`meta[layout]`, `DEFAULT_VIEW_LISTERS` for `default_template`/`default_layout`), the refusal builder and the message helper, so `PostsController` and `Settings::PostTypesController` iterate one table. The post type check runs with `@post_type || current_site.post_types.new(@data_term)`, the record the create form used.

### D6. Normalize the options row in `Metas#options`

`options` returns an empty indifferent hash for any stored value that is not a Hash, so `get_option`, `writable_options` and every caller work on a corrupt row; the row is replaced the next time an option is written (an engine write, the same as today's `set_option` on a valid row). `restore`'s guard goes back to `get_option('status_default')`, and the post type's two inline `is_a?(Hash)` guards stay because they read the raw row on purpose (they compare the stored decorator option before a write). PR #1302 rewrites `options` for same-instance reads; this branch adds the non-Hash branch to whichever version merges second.

### D7. Refuse malformed containers in the writers, answer with a flash in admin

`set_metas`/`set_options` raise `CamaleonCms::Metas::InvalidContainer` (an `ArgumentError`) for a present container that is neither a Hash nor `ActionController::Parameters`; nil and blank stay no-ops. `AdminController` rescues it like `RecordInvalid`: a flash error and a redirect back for a submitted save, re-raised on GET/HEAD. The post save keeps its up-front refusal (friendlier, before any write) and adds `field_options` to it so the post save has one policy for malformed containers. `PluginRoutes.fixActionParameter` is unchanged.

### D8. `cama_t` keeps the lookup options

The fallback is `I18n.t(key, **args.slice(:scope, :separator, :raise, :throw), locale: :en)` on a copy of the options: the interpolation values are the only thing withheld, so the fallback is a raw template interpolated once, and `raise: true` raises for a key missing everywhere, as in 2.9.4.

### D9. The scan task lists what the write rules would refuse, without a request

Outside a request the hooks cannot be dispatched, so the task compares a stored template/layout against the site's theme view files (`views/template_*`, `views/layouts/*`, the same globs the listers use) and says a plugin hook may still offer the value. It reads each post's options row raw, listing a non-object row as unreadable and continuing, and runs the content detector on the `summary` meta. The upgrade note replaces "no operator action is needed" with the task.

### D10. Destroy the named new-post buffer on create

`create` reads `params[:post][:draft_id]` on its own (it is not a post attribute) and destroys `@post_type.posts.drafts.where(post_parent: nil, user_id: cama_current_user.id).find_by(id:)` after the post is saved; the previous code looked the id up in the permitted attributes, where it never was.

### D11. One pass per param group

`post_params_refusals` walks each group once: a key is folded, refused as reserved, as a non-word, or (non-admin) as an unoffered value, else passed. The reserved and offered key sets are disjoint, so the message set is unchanged; no spec asserts message order. `cama_hash_param?` becomes one helper on `AdminController`, used by the post save, the post type check, the frontend comment guard and `cama_permitted_field_options`.

## Risks / Trade-offs

- **[A plugin submits a non-ASCII meta key]** → Its save is now refused with the key named. No surveyed consumer does; `docs/ai/ecosystem.md` records the rule.
- **[A plugin's `update_post` hook relied on running before the refusal]** → It now runs only for an accepted save, which is what its authors expect of a save hook.
- **[`set_metas`/`set_options` raise where they used to iterate]** → Only a present non-hash container raises; every surveyed caller passes a hash, request parameters or nil. Admin callers get a flash; frontend and rake callers surface the argument error, as any other bad argument.
- **[PR #1302 touches `Metas#options`]** → The non-Hash branch is one line; merge order is noted in the PR body.
- **[The scan cannot see hook-offered templates]** → It says so in each line; an operator checks the named value against the plugins that offer templates.
- **[MySQL is not in CI]** → The key rule and the status rule are exact-match, so SQLite exercises them fully; the collation facts are recorded here and in the code comment.
