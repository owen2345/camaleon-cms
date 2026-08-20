# Design — harden-media-pagination-and-lookup-docs

## Context

See `proposal.md` — Why. Load-bearing facts:

- The only caller of `cama_uploader.objects` is `Admin::MediaController` (`init_media_vars` sets
  `@tree`; `index` and `ajax` paginate it). The AWS `bucket.objects` calls are the S3 SDK,
  unrelated.
- The base `CamaleonCmsUploader#objects` returns an `ActiveRecord::Relation`
  (`get_media_collection.where(...)` or `.take.try(:items)`), or whatever an
  `uploader_list_objects` hook substitutes.
- The local override exists *only* to run `cama_fix_legacy_thumb_item` (a `File.exist?` per
  image) over every item; it forces `.to_a`, which also defeats `will_paginate`'s SQL pagination
  (the controller then uses `will_paginate/array`, in memory).
- Media browser items are media-collection records carrying `thumb`/`url`/`name`/`folder_path`/
  `is_folder`/`file_type`; the fixup mutates `item['thumb']` for display only.
- `cama_prepare_browser_page` runs after pagination, so an AR relation is loaded once and its
  records are mutated in place; the view then iterates the same loaded page.

## Goals / Non-Goals

**Goals**

- Restore DB-level pagination for the media browser and confine the per-image filesystem check to
  the rendered page.
- Keep S3/base behavior identical (the seam is a no-op there).
- Document M29 and M30 accurately; pin the #1183 lookup isolation the maintainer chose to keep.

**Non-Goals**

- No M29 code change — no host app appends `assets.paths` after the engine; both use
  `manifest.js`. Documentation only.
- No M30 code change — the maintainer signed off (2026-08-09) on keeping the #1183 isolation:
  merging controller prefixes into an entirely-theme-scoped explicit render would reopen the
  cross-theme / per-site-override leak #1183 closed, for zero consumers. Documented, and the
  isolation is pinned by a spec so it is not silently reverted.
- No change to the `uploader_list_objects` hook contract — a hook that returns an Array still
  paginates in memory (its choice); the fix targets the default relation path.

## Decisions

1. **Delete the local `objects` override; add `cama_prepare_browser_page`.** With the fixup moved
   out, the override is a pure `super` passthrough, so it is removed rather than left calling
   `super`. The base uploader gains `cama_prepare_browser_page(items) => items`; the local
   uploader overrides it to run `cama_fix_legacy_thumb_item` per item and return them. The media
   controller wraps both `@tree.paginate(...)` sites (`index`, `ajax`) with it.
   - Rejected: paginating inside the uploader (larger surface, changes the controller contract);
     a controller `case uploader.class` (leaks uploader knowledge into the controller).
2. **Retarget the existing `#objects` legacy-thumb unit specs to the seam.** The fixup logic is
   unchanged — only its call site moves — so the three cases now drive
   `cama_prepare_browser_page`, and a new case asserts `objects` returns a relation
   (`be_a ActiveRecord::Relation`), pinning the pagination contract.
3. **M30 = pin the isolation, document the limitation.** A `LookupContext`-level spec asserts that
   an entirely-theme-scoped explicit prefix list does not merge `self.prefixes`
   (`cama_theme_scoped_prefixes` returns the scoped list), so the deliberate #1183 behavior is
   guarded. The changelog states the known limitation for explicit-prefix renders.

## Risks / Trade-offs

- [A hook that returns a non-relation still materializes] → unchanged from today and out of
  scope; the default path (the real cost) is fixed.
- [`cama_prepare_browser_page` mutating a loaded relation page] → the page is loaded once by the
  seam's `each`; the view iterates the cached records, preserving the mutation. Verified by the
  request-level index behavior plus the unit seam spec.
- [M30 stays a known limitation] → accepted and signed off; zero consumers, and the alternative
  reopens a deliberate isolation.

## Migration Plan

Code + docs; no schema or data changes. Deploy normally; rollback = revert the commits.
