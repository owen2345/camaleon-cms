# Roll back a refused site settings save

## Why

`CamaleonCms::Admin::SettingsController#site_saved` stored the name, the slug and the description of
the site first. Then it stored the options, the metas and the custom-field values, with no
transaction. Camaleon refuses these parts of the save:

- a custom-field value with unsafe content or an invalid group number
- custom-field `values` in a shape that the shared permit cannot read
- an options or metas container that is not a set of fields

The refused save kept the parts that it stored before the refused part.

With more than one site, Camaleon finds the site of a request by its host. The slug of a site is
that host. A refused save with a new slug kept the new slug. The answer of the refusal redirects
back to the form, which is on the old host. That host named no site, so Camaleon redirected the
browser to the main site. The flash of the refusal belongs to the old host, so no page showed the
message.

## What Changes

- The site settings save writes in one transaction, as the post save and the draft save do. The
  transaction holds the site, its options, its metas and its custom-field values.
- A refused site settings save stores nothing. The site keeps its slug, so the redirect of the
  refusal leads to the form of the site, with the message.
- The answer does not change. It is a redirect back with a flash, or the refusal as text with a
  422 for an XHR without `cama_ajax_request`.
- A site asks for the reload of the routes after the commit of its transaction, for a create, a
  new slug and a delete. Before, it asked in the transaction. After a rollback, `PluginRoutes.get_sites`
  then kept the slug that was not stored.
- `docs/upgrading-to-2.9.5.md` says what a refused site settings save stores now.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: the requirement "A refused value rolls the save back and surfaces
  as an error" now holds for the site settings save too.
- `multisite-route-draw-readiness`: a new requirement for the moment at which a site asks for the
  reload of the routes.

## Impact

- `app/controllers/camaleon_cms/admin/settings_controller.rb`: the transaction.
- `app/models/camaleon_cms/site.rb`: the reload of the routes after the commit.
- `app/controllers/camaleon_cms/admin_controller.rb`: the comment of
  `rescue_from ActiveRecord::RecordInvalid`.
- Specs: a new request spec, `spec/requests/admin/settings/refused_site_save_spec.rb`, and new
  examples in `spec/lib/plugin_routes_reload_once_spec.rb`.
- `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md`.
- Ecosystem: the action calls no hook, and no plugin or theme overrides it. No surveyed plugin or
  theme changes the slug of a site or destroys a site.
