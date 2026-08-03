# Proposal: scoped-upload-roots-and-scan-narrowing

## Why

The `2.9.2..master` regression audit (H11, H12) found the upload hardening from #1198–#1211
rejecting legitimate work: plugin and job uploads staged anywhere outside `public/` or
`Dir.tmpdir` fail with `Invalid file path`, animated SVGs and re-crops of already-stored files are
refused as malicious, and ordinary prose containing `data :` trips the scheme detector.

A follow-up security review of those findings showed the controls are load-bearing and cannot
simply be relaxed: `formats` defaults to `'*'` and is supplied by `params[:formats]`, so there is
no server-enforced extension allowlist; uploads are served same-origin from `public/`; and
`MediaSecurityHeaders` only covers `.svg` — and does not run at all on hosts where the web server
serves `public/` directly. `Admin::MediaController#crop` also passes `params[:cp_img_path]`
straight into the path argument, so the allowed roots are what stops a request from reading
arbitrary files. This change therefore takes only the narrowings that provably preserve the
security properties, and leaves the HTML-upload question to a separate change that must add a
server-side extension policy first.

## What Changes

- Upload path validation accepts **caller-supplied** additional roots
  (`upload_file(path, allowed_roots: [...])`, same for `cama_tmp_upload`), so plugins, jobs and
  imports can stage files under `Rails.root/tmp`, `storage/`, or a mounted share. Extra roots come
  from application code only; nothing derived from request parameters may widen them, and the
  default root set for request-driven uploads is unchanged.
- The private-media directory is an allowed root while the uploader is in private mode, so
  cropping private media works without widening the roots for anything else.
- SVG uploads may use the SMIL animation elements `animate` and `set`. Event-handler attributes
  (including `onbegin`/`onend`/`onrepeat`), `script`, `foreignObject`, `handler`, and
  `javascript:`/`data:` URIs stay rejected — the animation *element* is not a script vector, the
  handler attribute is, and that check is unchanged.
- Content already stored under `Rails.public_path` is not re-scanned when it is used as an upload
  source (re-crop, same-site URL). Such a file is already publicly served, so re-scanning it
  reduces no exposure; remote downloads, `data:` payloads, and any source outside the public root
  are scanned exactly as before.
- The blocked-scheme pattern tolerates only the characters browsers actually strip from URLs
  (TAB, LF, CR) between scheme characters, instead of all whitespace, so prose such as
  `Sample data : 42` is no longer reported as malicious. The documented evasions
  (`jav<TAB>ascript:`, `java<LF>script:`) remain blocked.

**Explicitly out of scope:** allowing HTML uploads. Re-permitting them without a server-side
extension policy would re-open stored XSS in the site origin, because uploaded files are served
same-origin and the response-header middleware is bypassed in the common production deployment.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `upload-path-security`: the allowed-root set becomes extensible by trusted callers and by
  private mode, with an explicit prohibition on request-derived roots.
- `upload-content-security`: content already under the public root is exempt from re-scanning,
  and scheme-whitespace tolerance narrows to browser-stripped characters.
- `svg-upload-sanitization`: `animate`/`set` are no longer banned elements, while the
  event-handler, `script`, `foreignObject` and URI rules are unchanged.

## Impact

- `lib/camaleon_cms/uploader_path_security.rb` (`cama_canonical_upload_path` extra roots)
- `lib/camaleon_cms/uploader_pipeline.rb` (thread `allowed_roots`; skip re-scan for public sources)
- `lib/camaleon_cms/content_security.rb` (scheme pattern), `lib/camaleon_cms/svg_content_checker.rb`
  (banned tags)
- Specs under `spec/lib/camaleon_cms/`, `spec/lib/svg_content_checker_spec.rb`, and a request spec
  pinning that `cp_img_path` still cannot escape the default roots
