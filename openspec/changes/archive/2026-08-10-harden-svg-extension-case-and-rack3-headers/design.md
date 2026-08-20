# Design — harden-svg-extension-case-and-rack3-headers

## Context

Two independent case-sensitivity defects on the same SVG defense-in-depth path (audit L5, L6):

- Scan time: `UploaderContentSecurity#content_unsafe?` branches on `filename&.end_with?('.svg')`
  to send SVG bytes to `SvgContentChecker` (which bans `foreignObject`, `handler`, `form`, `meta`,
  `base`, `style`, `link`, and every `on*` attribute). Non-SVG content goes to the generic
  `ContentSecurity::SUSPICIOUS_PATTERNS` scan, whose `BLOCKED_ELEMENTS` list does NOT include
  `foreignObject`/`handler`. So an SVG whose only vector is one of those tags is caught for `.svg`
  and missed for `.SVG`.
- Serve time: `MediaSecurityHeaders` matches `%r{\A/media/.*\.svg\z}` and sets mixed-case header
  keys. Uppercase paths miss the headers; mixed-case keys violate Rack 3.

`self.class.get_file_format` already downcases the extension for format classification, so
uppercase-extension SVGs are accepted uploads — the case-sensitivity is a real gap, not a
theoretical one.

## Goals / Non-Goals

**Goals**

- Route any-case SVG uploads through the SVG parser.
- Apply the `/media/` SVG response headers to any-case SVG paths.
- Emit Rack-3-compliant lowercase header keys.

**Non-Goals**

- No change to WHAT either ruleset blocks — only the case of the extension gate. The two rulesets'
  contents were already reconciled deliberately (see `SvgContentChecker` comment); this change only
  ensures the SVG bytes reach the SVG ruleset regardless of extension case.
- No normalization of stored filenames — files keep the case the client sent.

## Decisions

1. **One case-insensitive seam, `File.extname(name).casecmp?('.svg')`.** Used by both `svg_upload?`
   and `content_unsafe?`. `File.extname` + `casecmp?` is exact (only the extension, case-folded),
   avoiding an `end_with?('.svg')` that would also match a file literally suffixed but not extensioned.
   Rejected: downcasing the whole path (allocates, and would fold case in the directory portion too).
2. **`SVG_PATH_PATTERN` gains `i` rather than an explicit `[Ss][Vv][Gg]`.** The `i` flag also folds
   the literal `/media/` segment, which is harmless — at worst it adds inert protective headers to a
   non-existent `/MEDIA/...` path; it never removes protection.
3. **Lowercase header keys.** Rack 3 requires them; `Rack::Headers`/ActionDispatch lookup stays
   case-insensitive, so existing readers (`response.headers['X-Content-Type-Options']`) are
   unaffected. A unit spec drives the middleware with a plain downstream app to assert the raw key
   casing, since the framework's case-insensitive lookup hid the defect from the request spec.

## Risks / Trade-offs

- [`i` on the whole path pattern over-matches `/MEDIA/`] → accepted; adding headers to a
  non-canonical path is inert, and real media URLs are lowercase `/media/`.
- [Uppercase-extension SVGs now take the SVG-parser path at scan time] → this is the intended
  hardening; the SVG ruleset is stricter, so nothing that passed before is newly blocked except the
  SVG-only vectors that were always meant to be blocked.

## Migration Plan

Code + specs; no schema or data changes. Deploy normally; rollback = revert the commits.
