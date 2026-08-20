## Why

The 2026-08 regression audit batched the media/infra residuals as PR 7 (M27, M29-doc, M30-doc) —
the last of the medium-fix sequence.

- **M27** — the local media browser paginates in memory and stats the filesystem for every image
  in a folder on every page view. `CamaleonCmsLocalUploader#objects` calls `super`, then
  `.to_a` (materializing the whole folder's media records) and runs the legacy-thumb fixup —
  which does a `File.exist?` per image — over **all** of them. The controller then paginates that
  Array with `will_paginate/array` (in-memory). 2.9.2 returned the relation, so pagination was
  SQL `LIMIT`/`OFFSET` and the fixup touched only the rendered page. Folders with thousands of
  files load fully and re-stat every image per page.
- **M29** (doc) — the engine's assets precompile list is a boot-time snapshot; a Sprockets-3 host
  app that appends plugin/theme asset roots in its own initializer (after the engine's) loses
  those files in production. The ecosystem sweep found neither host app does this (both drive
  precompilation from `manifest.js`), so this is documented, not code-fixed.
- **M30** (doc) — the #1183 theme-scoped lookup guard deliberately does **not** merge the
  controller/global prefixes when an explicit `render prefixes:` is entirely theme-scoped, to
  keep per-site-override and plugin prefixes from leaking into a theme partial. The residual is a
  `MissingTemplate` for an explicit-prefix render whose template actually lives under a controller
  prefix. Zero stock and zero ecosystem `render prefixes:` consumers hit this, and the maintainer
  signed off (2026-08-09) on **keeping the isolation** rather than reopening it — so this is
  documented as a known limitation, with the deliberate behavior pinned so it is not "fixed" later.

## What Changes

- **M27**: `CamaleonCmsLocalUploader#objects` returns the relation unchanged (the override that
  materialized and fixed up the whole folder is removed). The legacy-thumb fixup moves to a
  polymorphic page seam, `cama_prepare_browser_page`, applied by the media controller to the
  paginated page only (a no-op on the base/S3 uploaders). Pagination is again DB-level
  (`LIMIT`/`OFFSET`), and the per-image `File.exist?` runs over one page, not the whole folder.
- **M29**: a changelog note for Sprockets-3 host apps that append asset roots after the engine.
- **M30**: a changelog note plus a spec pinning the deliberate #1183 isolation (an entirely
  theme-scoped explicit render does not merge the controller prefixes).

## Capabilities

### New Capabilities

- `local-media-pagination`: `objects` returns a lazy relation so the media browser paginates at
  the database, and the legacy-thumbnail fixup is applied to the rendered page only (polymorphic,
  no-op for non-local uploaders).

### Modified Capabilities

None.

## Impact

- `app/uploaders/camaleon_cms_uploader.rb` (base page seam),
  `app/uploaders/camaleon_cms_local_uploader.rb` (drop the `objects` override, add the seam),
  `app/controllers/camaleon_cms/admin/media_controller.rb` (apply the seam at the two paginate
  sites), `CHANGELOG.md`.
- Specs: `spec/uploaders/local_uploader_spec.rb` (retarget the legacy-thumb `#objects` cases to
  the page seam, add the lazy-relation assertion), new
  `spec/initializers/theme_scoped_lookup_spec.rb` (pin the M30 isolation).
- No routes or schema changes. Behavior deltas: large media folders paginate at the DB and stat
  only the visible page; documentation gains the M29/M30 notes. The #1183 lookup isolation is
  unchanged.
