# Proposal: fix-content-sanitization-scope

## Why

The `2.9.2..master` regression audit (H7) confirmed that #1206's save-time sanitization destroys
legitimate content far beyond its security intent: the Rails default allowlist silently strips
tables, figures, and common attributes (`style`, `id`, `target`, `rel`) from every untrusted
save, and the fail-closed rule sanitizes *all* out-of-request saves — rake imports, seeds, and
plugin pipelines mutate developer-controlled content with no way to opt out. The audit also
confirmed H10: activating the bundled `camaleon_first` theme 500s mid-activation because a
Rubocop line-length rewrite introduced `helper.capture` calls into a hook that runs in controller
context (fixed in the same branch as a trivial restoration, outside this change's capability
scope).

## What Changes

- Untrusted post saves keep structural, non-executable markup: table elements
  (`table thead tbody tfoot tr td th caption col colgroup`), `figure`/`figcaption`, `u`, `s`,
  `hr`, and the attributes `id`, `style` (CSS-scrubbed by the sanitizer), `target`, `rel`,
  `colspan`, `rowspan`. Scripts, iframes, event handlers, and `javascript:` URLs stay stripped;
  the security posture for executable content is unchanged. The widened lists apply to
  `Post#content` only — `NormalizeAttrs` consumers (descriptions, `NavMenuItem#name`) keep the
  strict defaults.
- Developer-controlled pipelines get an explicit opt-out: calling `post.unfiltered_content!`
  before save stores content unchanged. It is exposed with no `=` writer, so it is not
  mass-assignable; without it, out-of-request saves keep failing closed exactly as specified
  today.
- No change to role gating: admins bypass via `manage :all`, the `post_content_unfiltered_html`
  grant works per post type, and the Editor exclusion stays (deliberately not backfilled).

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `post-content-sanitization`: the untrusted-save requirement gains the structural-markup
  preservation contract, and the no-user-context requirement gains the explicit
  `unfiltered_content` opt-out for developer-controlled saves.

## Impact

- `app/models/camaleon_cms/post.rb` (allowlist constants, opt-out accessor, sanitize call)
- `app/models/camaleon_record.rb` (`cama_sanitize_translatable` accepts optional
  `tags:`/`attributes:`; callers without arguments are unaffected)
- `app/apps/themes/camaleon_first/main_helper.rb` (H10: string literals restore activation)
- `spec/models/post_content_sanitization_spec.rb`, `spec/features/admin/themes_spec.rb`
