## Context

The request params reach the post's metas and options through two paths:

- **Posts:** `PostsController#create`/`#update` run `save_post_with_fields`, one transaction of `post.save`/`update`, `set_metas(params[:meta])`, `set_field_values(...)` and `set_options(params[:options])`. A parent validation failure returns false and the action re-renders the form. A refused custom-field value raises `RecordInvalid`, which `AdminController` turns into a flash error and a redirect.
- **Drafts:** `DraftsController#create`/`#update` save the buffer with `save(validate: false)`, then call `set_params(params[:meta], ..., options)`, and answer JSON.

Three facts shape the fix:

- **The offered lists need request context.** They come from `SiteHelper#cama_get_list_template_files`/`#cama_get_list_layouts_files`: the current theme's `views/template_*` and `views/layouts/*`, passed through the `post_get_list_templates`/`post_get_list_layouts` hooks. `SiteHelper` is already included into controllers through `RequestContextConcern`, so the controller can call the same methods the editor's selects use.
- **`restore` trusts the stored option.** It writes `@post.options[:status_default]` straight into the column with `update_column`, and checks only `authorize! :update`.
- **`create`/`update` already guard publishing.** `get_post_data` downgrades `published` to `pending` for a user who `cannot?(:publish_post, @post_type)`.

## Goals / Non-Goals

**Goals:**
- **One check for both paths:** posts and drafts share a single check of the request's `meta`/`options`, applied before anything is written.
- **Same publish rule in `restore`:** it follows the rule `get_post_data` already applies to `create` and `update`.

**Non-Goals:**
- **Category options:** unchanged (storage only; see proposal).
- **Stored values:** no render-time filtering of a stored template or layout. The frontend's existing `template_exists?` lookup stays as it is, and nothing already stored is rewritten or migrated.
- **Server-side writers:** calls to `set_meta`/`set_option` from the engine, plugins or themes stay unrestricted.
- **Malformed containers:** a `meta`/`options` param that is not a hash keeps today's behavior. That is pre-existing and not part of this threat.

## Decisions

### D1. Check the request params in the controller, not a model validation

The threat is request input. The engine and ecosystem legitimately write the same keys server-side: `trash` stamps `status_default`, visits bump a counter, and a theme may assign a template on activation. The offered lists also need the current theme and a hook dispatch whose receiver is the controller, the ecosystem contract `hook_run` handlers rely on.

**Alternative rejected:** a `Post` validation. It would block those server-side writers and would have to rebuild theme and hook context inside the model. Core's post type option allowlist (`post_type_meta_params`) already lives in its controller for the same reason.

### D2. A shared private check, run before any write

`PostsController` gets one private method that returns the refusals for the current request, each with the field and an i18n message. `DraftsController` inherits it from `PostsController`.

- **`save_post_with_fields`:** runs the check first. With refusals, it adds them to `post.errors` and returns false before the transaction starts, so the form re-renders with the errors (the same outcome as a parent validation failure) and nothing is written.
- **Drafts `create`/`update`:** run it before `save(validate: false)` and answer `{ error: [...] }` without saving.

Checking up front means nothing has to be rolled back.

### D3. Trust

- **Template and layout rule:** it skips administrators (`cama_current_user.admin?`), per rule 1 of the gating rule. No permission is added, because no non-admin needs to render a view the editor never offered. The editor only offers the listed names.
- **Engine-maintained keys:** refused for everyone, administrators included. A submitted value is a corrupt record rather than a capability, the same reasoning as the contact form's structural values and the post type decorator-class rule.

### D4. Comparisons

- **What is checked:** values are compared as strings against the offered lists, computed once per request. `meta[template]` and `options[default_template]` are checked against the template list; `meta[layout]` and `options[default_layout]` against the layout list.
- **Non-string values:** a Hash or Array in one of those positions is not in any list, so it is refused.
- **Reserved keys:** a key is reserved when `key.to_s` starts with `_` or equals `visits` or `comments_count` (meta), or equals `status_default` or `draft_status` (options). Both string and symbol keys are covered.

### D5. `restore`

- **Trash only:** a post whose status is not `trash` gets a flash error and a redirect, with nothing written.
- **Status rule:** the stored `status_default` is kept only when it is `published`, `pending` or `draft`; anything else becomes `pending`. `published` becomes `pending` when `cannot?(:publish_post, @post_type)`.
- **Write path unchanged:** it keeps `update_column` and `update_extra_data`, as today.

### D6. The existing status-escaping spec

The `options[:status_default] -> trash -> update -> restore` example in `spec/requests/security/post_status_output_escaping_spec.rb` planted its payload through the path this change closes. Its admin-listing escaping assertion stays useful, so the payload is planted with `update_column`, and the new request spec covers the closed path.

## Risks / Trade-offs

- **[A plugin or theme form submits a template value it never registers through `post_get_list_templates`]** → Such a value would now be refused for non-admins. Registering the value through the hook fixes it. The upgrade guide and `docs/ai/ecosystem.md` say so. No surveyed consumer submits one.
- **[After a theme switch, a post's stored template is no longer offered]** → The editor's select cannot pre-select it and submits blank. That is today's behavior, and blank is accepted, so saves keep working.
- **[Non-publishers used `restore` to bring published posts back live]** → Those posts now return as `pending` for a publisher to re-publish. The upgrade guide notes it.
- **[Values stored before the change: an unlisted template, a clobbered `_default`, a crafted `status_default`]** → None is rewritten. The restore rule neutralizes `status_default`, the other two only affect the post they were written to, and saving the post again (as a non-admin) re-runs the check.
