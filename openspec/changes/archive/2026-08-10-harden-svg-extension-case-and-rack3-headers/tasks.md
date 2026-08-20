## 1. L5 — case-insensitive SVG extension routing (commit 1)

- [x] 1.1 Red-first: `spec/lib/camaleon_cms/uploader_content_security_spec.rb` — an uppercase `.SVG`
      carrying an SVG-only banned tag (`foreignObject`) is routed to the SVG parser and rejected;
      a clean uppercase `.SVG` is accepted through the SVG checker, not the generic scan. Add the
      uppercase-`.SVG` header cases to the middleware specs (see task 2).
- [x] 1.2 `UploaderContentSecurity`: `content_unsafe?` and `svg_upload?` branch on a
      `cama_svg_extension?(name)` seam (`File.extname(name).casecmp?('.svg')`).
- [x] 1.3 `MediaSecurityHeaders::SVG_PATH_PATTERN` gains the `i` flag.

## 2. L6 — Rack 3 lowercase header keys (commit 1, same file)

- [x] 2.1 Red-first: new `spec/lib/camaleon_cms/media_security_headers_spec.rb` unit-drives the
      middleware and asserts lowercase header keys + case-insensitive path match;
      `spec/requests/media_security_headers_spec.rb` gains an uppercase `.SVG` served-inline case.
- [x] 2.2 `MediaSecurityHeaders` emits `x-content-type-options` / `content-security-policy`.

## 3. Verification and CI parity

- [x] 3.1 Touched specs green; broader upload/security suite green.
- [x] 3.2 `bin/rubocop` clean on touched files, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 4. OpenSpec + PR protocol

- [x] 4.1 `openspec validate harden-svg-extension-case-and-rack3-headers --strict` passes; archive
      on-branch (syncs `media-serving-security` + `upload-content-security`); commit the archived
      change (no `[skip ci]` — heads the first push).
- [x] 4.2 Push, open the PR (What and Why + User-Visible Impact).
- [x] 4.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
