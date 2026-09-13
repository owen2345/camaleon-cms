## Why

The admin post save stores every submitted `meta[...]` and `options[...]` key as given (`set_metas(params[:meta])`, `set_options(params[:options])`, and the drafts save's `set_params`). Verified through the real endpoints:

- **Template and layout names.** A post's author can store any template or layout name, bypassing the list the form offers. Any template the view lookup finds then renders on the public page. An admin template makes that page raise a 500 on every request, and the admin layout renders on the public page.
- **Options hash.** `meta[_default]` replaces the post's whole options hash, which breaks the page permanently.
- **Publish bypass.** A contributor without the publish permission can save `options[status_default]=published` and then call `restore`, which checks only `:update`. `restore` copies that option into `status`, so the contributor publishes the post.

## What Changes

- **Template and layout values from a non-admin:** a post save or draft save that carries `meta[template]`, `meta[layout]`, `options[default_template]` or `options[default_layout]` is refused unless the value is blank or one the post form offers for that post type (the theme's templates and layouts, as extended by plugin hooks). The error names the field. Administrators are not restricted.
- **Engine-maintained keys, from anyone:** the save refuses these keys when they arrive in request params, with an error naming the key. The engine writes them itself, so a submitted value is a corrupt record, not a capability.
  - meta keys starting with `_`, such as `_default`;
  - the counters `visits` and `comments_count`;
  - the options `status_default` and `draft_status`.
- **Other keys unchanged:** every other `meta`/`options` key is still stored as given. Plugins and themes rely on it, for example cama_meta_tag's `options[seo_*]`, camaleon_sitemap_customizer's `options[hide_in_sitemap]`, and the `meta[product_specifications]` field in e-commerce themes.
- **Restore:** it requires a trashed post. It restores a stored status only when that status is `published`, `pending` or `draft` and the acting user may set it; a non-publisher's post returns as `pending` instead of `published`.
- A refused save stores nothing. The post, its metas, field values and options are rolled back together, as a refused custom-field value already is.
- **Out of scope:** category options (`@category.set_options(params[:meta])`) keep accepting any key. Core reads back only `thumb` and `keywords`, and both render escaped. Nothing stored before this change is rewritten.

## Capabilities

### New Capabilities
- `post-editor-write-integrity`: which request-supplied post metas and options a save accepts (theme-offered templates and layouts, no engine-maintained keys), and which status a restore may give a post.

### Modified Capabilities

## Impact

- **Code:** `app/controllers/camaleon_cms/admin/posts_controller.rb` (the save transaction, `restore`) and `app/controllers/camaleon_cms/admin/posts/drafts_controller.rb` (`set_params` calls), plus a small shared check and its i18n error messages.
- **Ecosystem:** the template and layout lists already run the `post_get_list_templates`/`post_get_list_layouts` hooks, so a plugin that adds templates keeps working. No surveyed consumer submits an engine-maintained key. camaleon_website's `sky` theme only reads `default_template`.
- **Docs:** `docs/security/permissions.md` (the remedy rule's pieces), `docs/ai/ecosystem.md` (the hardening note), `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md`.
- **Specs:** request specs reproducing the three issues through the real endpoints, as a contributor, an editor and an admin.
