# Proposal — filter-theme-field-value-saves

## Why

The 2.9.2 mass-assignment hardening (eba56d6f) routed every admin custom-field value save
through an allowed-slugs filter — except two theme-settings paths that still pass raw request
params into `set_field_values`: the `theme_fields` param in `save_theme`, and the bundled
`themes/new` theme's `on_theme_settings` hook handler. The surface is not admin-only: it is
gated by `authorize! :manage, :theme_settings`, a grantable role capability, so any role
granted theme settings can write arbitrary field-value rows (any `custom_field_id`, any slug,
any value) onto the theme. The bundled handler additionally issues its own redirect inside the
hook, colliding with `save_theme`'s redirect into a `DoubleRenderError` 500 after the raw
write commits.

## What Changes

- `CustomFieldsConcern#cama_permitted_field_options` accepts the request param key to filter
  (`param_key:`, defaulting to `:field_options`) so the same allowed-slugs permit can cover
  sibling payload params; the eight existing call sites are unchanged.
- `save_theme` filters `theme_fields` through the concern (`param_key: :theme_fields`) instead
  of passing it raw; registered slugs posted through `theme_fields` keep saving.
- The filter drops groups left empty after filtering, so a submission carrying no registered
  slug returns `{}` and `set_field_values` no-ops instead of running its `delete_all` and wiping
  the object's stored values (pre-existing across all its call sites; branch-review fix).
- The `themes/new` `on_theme_settings` handler no longer saves at all: `save_theme` already
  persists `field_options` generically, so the hook's duplicate write is removed along with its
  broken redirect (the branch's first pass filtered the hook's write; branch review simplified it
  away). The other bundled themes and the theme generator template were already clean.

## Capabilities

### New Capabilities

- `custom-field-value-filtering`: admin custom-field value saves accept only slugs registered
  under the target's placement scope; theme-settings saves (both payload params and the bundled
  theme's hook handler) participate, and the bundled custom-save path answers with the standard
  single response.

### Modified Capabilities

_None._

## Impact

- `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb` (`param_key:` kwarg)
- `app/controllers/camaleon_cms/admin/settings_controller.rb` (`save_theme` `theme_fields`)
- `app/apps/themes/new/custom_helper.rb` (`theme_custom_settings` save branch)
- New request specs: `theme_fields` filtering and the `themes/new` hook path, driven by a
  `theme_settings`-only role
- No migration; no data re-keying; `theme_fields` remains a working param for registered slugs
  (external themes posting it keep functioning); no API removal
