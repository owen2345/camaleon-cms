## 1. M27 — DB-level media pagination + page-scoped thumb fixup (commit 1)

- [x] 1.1 Retarget the three `#objects` legacy-thumb cases in `spec/uploaders/local_uploader_spec.rb`
      to `cama_prepare_browser_page`, and add a case asserting `objects('/')` returns an
      `ActiveRecord::Relation` (responds to `limit`) — red on master, where `objects` returns a
      materialized Array. Add a base/S3 no-op case.
- [x] 1.2 Base `CamaleonCmsUploader#cama_prepare_browser_page(items) => items`; `CamaleonCmsLocalUploader`
      drops the `objects` override and overrides `cama_prepare_browser_page` to run the
      legacy-thumb fixup per item.
- [x] 1.3 `Admin::MediaController`: wrap the `index` and `ajax` `@tree.paginate(...)` results with
      `cama_uploader.cama_prepare_browser_page(...)`.
- [x] 1.4 Spec files green; rubocop clean on touched files; commit M27.

## 2. M30 — pin the #1183 lookup isolation (commit 2)

- [x] 2.1 New `spec/initializers/theme_scoped_lookup_spec.rb`: an entirely theme-scoped explicit
      prefix list yields `cama_theme_scoped_prefixes == the scoped list` (self.prefixes not
      merged); a mixed list (theme + plugin prefix) yields nil (merge as before). Pins the
      deliberate isolation.
- [x] 2.2 Add a clarifying comment at the guard noting the documented known limitation
      (explicit-prefix renders resolving to a controller-owned template are not merged — by design).

## 3. M29 + M30 — documentation (commit 3, docs-only, [skip ci])

- [x] 3.1 CHANGELOG: M29 note (Sprockets-3 host apps appending asset roots after the engine lose
      them in production; use `manifest.js`); M30 note (an explicit `render prefixes:` that is
      entirely theme-scoped is not merged with controller prefixes — deliberate #1183 isolation).

## 4. Verification and CI parity

- [x] 4.1 Full `bin/rspec` suite green.
- [x] 4.2 `bin/rubocop` clean, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 5. OpenSpec + PR protocol

- [x] 5.1 `openspec validate harden-media-pagination-and-lookup-docs --strict` passes; archive
      on-branch (syncs `local-media-pagination`); commit the archived change (no `[skip ci]` —
      heads the first push).
- [x] 5.2 Push, open the PR (What and Why + User-Visible Impact; protocol constraints), first
      push runs CI.
- [x] 5.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
