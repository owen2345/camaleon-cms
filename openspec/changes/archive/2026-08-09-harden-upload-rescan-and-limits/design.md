# Design — harden-upload-rescan-and-limits

## Context

See `proposal.md` — Why. All findings live in the shared uploader pipeline
(`lib/camaleon_cms/uploader_pipeline.rb`, `lib/camaleon_cms/content_security.rb`) and the
controller entry point (`runtime_uploader_concern.rb`). Load-bearing facts:

- `upload_file` scans at the top (line ~59), then fires `before_upload` (~84), then writes
  `settings[:uploaded_io]` (~101). `cama_trusted_for_unfiltered_upload?` gates the scan
  (permission `media_unfiltered_upload`, fails closed without a request — the
  `security-capability-gating` contract).
- `before_upload` handlers rebind `settings[:uploaded_io]` in place (the spec already states a
  handler "may replace the IO object but not its `path`"); `camaleon_image_optimizer` does this.
- `crop` re-enters `upload_file` after `cama_tmp_upload`, so `before_upload` fires again per crop.
- `cama_size_limit_error` is the single size gate for every path (`upload_file`, `cama_tmp_upload`,
  data-URI staging, and plugin callers passing `maximum:`).
- `ct` was restored to the controller chain by #1223 and runs `on_translation`; its default arm
  is `I18n.translate("camaleon_cms.common.#{key}", **args)` — byte-identical to
  `UploaderPipeline#cama_uploader_ct` for the no-hook case.
- The content scan is ~60 regexes: 58 `UNSAFE_EVENT_PATTERNS` matched in a loop plus the element
  and scheme patterns. The existing content-security spec pins *which inputs match*, not the
  pattern count or the returned identifier.

## Goals / Non-Goals

**Goals**

- N2: an untrusted uploader cannot launder bytes past the scan through `before_upload`.
- M26: a zero/blank `filesystem_max_size` stops blocking all uploads, at the one gate every
  caller shares.
- M25: cut the dominant scan cost (the 58-pattern loop) without changing what matches.
- M24: media-manager upload errors become plugin-overridable via `on_translation`.

**Non-Goals**

- N2 does not re-scan when the IO is unchanged (the top-of-method scan already covered it), and
  does not treat a `before_upload` handler as trusted — the rejected alternative.
- M25 does **not** reorder size/format validation relative to the scan: those checks sit after
  `before_upload` precisely so a handler can adjust `:formats`/`:maximum`, and moving them ahead
  of the hook would change that contract. The regex consolidation delivers the headline win
  without touching ordering. The `crop` double-scan (two separate entry-point calls) is left as
  a known cost — collapsing it needs cross-call state and has no audited correctness impact.
- No server-side extension policy (the deferred H11/N1 work); unchanged here.

## Decisions

1. **N2 = identity check across the hook.** Capture the IO object before `before_upload`; after
   it, if `settings[:uploaded_io]` is a different object and the uploader is untrusted, scan the
   substituted IO with the existing `file_content_unsafe?` and fail through
   `cama_upload_failure` on a hit. Keyed on object identity (`equal?`), not on whether a hook
   ran, so a handler that leaves the IO alone costs nothing and a permission-holder is never
   re-scanned. Rejected: unconditional re-scan (doubles cost for the common no-op hook);
   trusting `before_upload` output (the finding).
2. **M26 = `maximum <= 0` means unlimited** in `cama_size_limit_error`. The guard becomes
   `return if maximum.blank? || maximum.to_f <= 0 || maximum >= size`. One line, the shared gate,
   so `cama_contact_form`'s `maximum:` pass-through is covered without touching its code.
3. **M25 = one alternation for the event patterns.** `UNSAFE_EVENT_PATTERNS` collapses from 58
   regexes to a single `/(?:onabort|onafter|…)\w*\s*=/i` built from the same word list; the loop
   in `content_unsafe?` now iterates 3 patterns. Matching is identical (each old pattern was
   `/#{word}\w*\s*=/i`; the union factors the shared suffix). Verified against the existing
   bypass/keep-passing spec plus added event-word cases.
4. **M24 = `respond_to?(:ct)` dispatch in the concern.** `RuntimeUploaderConcern` overrides
   `cama_uploader_ct` to call `ct(key, args)` when the host responds to `ct`, else `super` (the
   pipeline's `I18n.t`). Controller uploads then run `on_translation`; non-controller includers
   (jobs, standalone) keep the `I18n` path. Default text is unchanged either way.

## Risks / Trade-offs

- [N2 re-scan on every crop where a handler rewrites bytes] → intended; that is the seam the
  finding is about, and it only runs for untrusted uploaders whose handler actually swapped the
  IO.
- [M25 consolidation changes the logged/returned pattern identifier] → callers only test
  truthiness and render a generic message; no spec asserts the identifier. A single combined
  identifier is still logged.
- [M24 routes controller messages through the hook] → the default translation is byte-identical;
  only a plugin that registered `on_translation` sees a change, which is the intended fix.

## Migration Plan

Code + docs; no schema or data changes. Deploy normally; rollback = revert the commits. M28 is a
changelog note only.
