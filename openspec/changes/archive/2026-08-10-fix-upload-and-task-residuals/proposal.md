## Why

Regression-audit lows in the uploads/media and operator-task surfaces (post-2.9.2 review): L3, L16,
L11, plus the L18 test gap and the L7 documentation note.

- **L3** — `Admin::MediaController#crop` renders `res['url'].to_s` and writes
  `set_meta('avatar', res['url'])` without checking whether `upload_file` failed. A failed upload
  returns `{ error: ... }` with no `url`, so the action rendered an empty 200 body (the avatar flow
  stored `""`) and overwrote the saved avatar meta with nil.
- **L16** — `cama_upload_failure` reads `settings[:remove_source]` (symbol only), but the first
  (malicious-content) rejection in `upload_file` runs *before* settings are deep-symbolized. A
  caller passing a string-keyed `remove_source` therefore left its staged file behind in the
  web-served `public/tmp`.
- **L11** — the theme generator and three repair rake tasks wrote operator output only to
  `Rails.logger`, so an operator running them from a terminal saw nothing (the log goes to a file).
- **L18** — the M27 media-pagination fix (#1242) had no end-to-end test proving the legacy-thumb
  repair reaches the rendered page; the unit specs only exercised the `.to_a` array path.
- **L7** — rows edited during the 2.9.1–2.9.2 sanitize-on-save era stored HTML-escaped entities
  and render visibly double-encoded once under the escape-at-render era; no repair task
  (document-only, per maintainer decision — each row self-heals on edit-and-resave).

## What Changes

- **L3**: `crop` surfaces an `upload_file` error like its other error paths (`render plain:`
  sanitized message) and skips the avatar meta write.
- **L16**: `cama_upload_failure` honors a string-keyed `remove_source` too, so the staged file is
  purged on the pre-symbolize failure path.
- **L11**: operator output goes to stdout as well as the log (a `report` lambda in the tasks, Thor's
  `say` in the generator).
- **L18**: a request spec asserts the repaired `.png` thumbnail URL appears in the rendered page.
- **L7**: a CHANGELOG upgraders note.

## Capabilities

### New Capabilities

- `media-crop-error-response`: the crop action surfaces upload failures instead of an empty success,
  and never writes a nil avatar meta on failure.

### Modified Capabilities

- `upload-staging-lifecycle`: staged-file cleanup on failure honors a string-keyed `remove_source`,
  covering the pre-symbolize (malicious-content) rejection path.

## Impact

- `app/controllers/camaleon_cms/admin/media_controller.rb` (L3),
  `lib/camaleon_cms/uploader_path_security.rb` (L16),
  `lib/tasks/{custom_fields_roles,site_custom_field_groups,cross_site_field_groups}.rake` and
  `lib/generators/camaleon_cms/theme_generator.rb` (L11), `CHANGELOG.md` (L7).
- Specs: crop request spec (L3), `uploader_helper_spec` (L16), the three rake-task specs (L11
  stdout), media `index` request spec (L18).
- No routes or schema changes.
