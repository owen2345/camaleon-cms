# Tasks — filter-theme-field-value-saves

## 1. Filter the theme_fields save (commit 1)

- [x] 1.1 Write the red request spec `spec/requests/security/theme_field_value_filtering_spec.rb`:
      a `theme_settings`-only role posts `save_theme` with a `theme_fields` payload carrying an
      unregistered slug — red because the value row is created; plus the green-by-design pin
      that a registered slug through `theme_fields` still saves.
- [x] 1.2 Add `param_key:` (default `:field_options`) to
      `CustomFieldsConcern#cama_permitted_field_options`; `save_theme` filters `theme_fields`
      through it (guard dropped — blank filters to `{}` and `set_field_values` no-ops);
      confirm red goes green.

## 2. Filter the bundled theme's custom-save hook (commit 2)

- [x] 2.1 Extend the spec: with the site's `_theme` option pointed at `new` and fields
      registered on that theme record, posting `save_theme` with `action_name=save_settings`
      and an unregistered `field_options` slug is red (row created, request raises
      `DoubleRenderError`); the single-redirect pin is red the same way.
- [x] 2.2 `themes/new` `theme_custom_settings` save branch: filtered
      `cama_permitted_field_options('Theme')` call, drop its `flash` + `redirect_to`;
      confirm both reds go green. Applied to BOTH the gem file and the identical committed
      duplicate `spec/dummy/app/apps/themes/new/custom_helper.rb` (the copy the suite loads).
      Red also surfaced that the old `redirect_to action: :settings` targeted a non-existent
      route (UrlGenerationError), not merely a DoubleRenderError — the drop fixes both.

## 3. Verification and delivery

- [x] 3.1 Gates: `bin/rubocop -A` (touched files only, before specs), full `bin/rspec`,
      `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 Archive the OpenSpec change on the branch (syncs the custom-field-value-filtering
      capability) and commit it as part of the PR.
- [x] 3.3 Push (no CI-skip marker — first run must cover the code), open the PR; only after
      that run exists, commit and push the short changelog entry with the skip-ci directive.
- [x] 3.4 Update the regression-audit memory (theme_fields gap → fixed).
