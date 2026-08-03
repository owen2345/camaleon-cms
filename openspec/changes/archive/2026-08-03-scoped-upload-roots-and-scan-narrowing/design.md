# Design: scoped-upload-roots-and-scan-narrowing

## Context

Audit items H11 and H12 report upload hardening rejecting legitimate work. A security review of
those reports (recorded in the PR discussion) established the constraints this design works
within:

- **No server-enforced extension allowlist.** `settings[:formats]` defaults to `'*'`
  (`uploader_pipeline.rb`), `CamaleonCmsUploader.validate_file_format` returns `true` immediately
  for `'*'`, and the value arrives as `params[:formats]` — the client picks its own restriction.
- **Uploads are served same-origin** from `public/media/<site_id>/`.
- **`MediaSecurityHeaders` covers only `.svg`**, and in the common production deployment
  (`public_file_server.enabled = false`, nginx/Apache serving `public/`) it does not run at all.
- **`Admin::MediaController#crop` passes `params[:cp_img_path]` into the path argument**, so the
  allowed roots are the control that stops a request from reading arbitrary files.

Consequently the content denylist is, today, the only thing preventing a media-permission holder
from storing an HTML file that executes in the site origin. That is why this change takes only
narrowings whose security property can be shown to survive, and defers the HTML question.

## Goals / Non-Goals

**Goals:**

- Let trusted server-side code stage uploads outside `public/` and `Dir.tmpdir`.
- Stop rejecting animated SVGs, re-crops of already-published files, and prose containing
  `data :`.
- Keep every request-reachable guarantee exactly as strong as it is today.

**Non-Goals:**

- Permitting HTML uploads or otherwise relaxing the element denylist for non-SVG content. That
  needs a server-side extension policy first (and the removal of `params[:formats]` as the
  authority), which is its own change.
- Allowing `foreignObject`: it embeds foreign markup, a different risk class from an animation
  element.
- Rewriting `crop` to resolve `cp_img_path` through a media-library key lookup. Worth doing, but
  it changes a request contract and belongs with the extension-policy work.

## Decisions

- **D1 — Extra roots are per-call arguments, not global configuration.** `allowed_roots:` is
  passed to `upload_file`/`cama_tmp_upload` and reaches `cama_canonical_upload_path` for that call
  only. A global config list would widen the roots for the request-driven `crop` sink as well,
  which is precisely the exposure the roots exist to prevent. Per-call scoping means the request
  path keeps the default roots no matter what any plugin configures.
- **D2 — Request parameters must not reach `allowed_roots:`.** The media controller builds its
  settings hash from explicit named keys, so no `params` value can land there; a request spec
  pins that an `allowed_roots` form field does not widen validation. The `before_upload` hook can
  still set it, which is intentional: hooks are application code.
- **D3 — Private mode adds the private root implicitly.** `enable_private_mode!` switches the
  uploader's root folder to `Rails.root/private`; while it is active that directory is a legal
  source. This is derived from uploader state, not from the request, and disappears when private
  mode is off.
- **D4 — The re-scan exemption keys on the canonicalized source path being under
  `Rails.public_path`.** Rationale: those bytes are already retrievable at a public URL, so
  scanning them again when they are re-used as a source removes no exposure — the crop output is
  the same content in the same origin. Deliberately *not* keyed on "is in the allowed roots"
  (which now includes private and caller roots) nor on "came from a same-site URL" (which can be
  a path the site does not publish). Remote downloads land in a Tempfile outside the public root
  and stay scanned.
- **D5 — Scheme tolerance narrows to `[\t\n\r]`.** The WHATWG URL parser removes exactly TAB, LF
  and CR from a URL, which is what makes `jav<TAB>ascript:` execute; the space character is not
  removed, so `data :` is not a URI and never was an evasion. Matching the browser rule exactly
  keeps every documented evasion blocked while ending the prose false positive. Rejected:
  requiring an attribute context (unavailable when scanning raw bytes), and dropping the scheme
  patterns entirely (loses real coverage).
- **D6 — `animate`/`set` leave `BANNED_TAGS`; `handler` and `foreignObject` stay.** The XML
  checker already rejects any attribute whose name starts with `on`, independent of element, so
  the animation-event vector (`onbegin`/`onend`/`onrepeat`) remains covered by the rule that
  actually describes it. The existing "SVG with onbegin animation event is rejected" scenario
  keeps passing unchanged, which is the clearest evidence the narrowing is safe.

## Risks / Trade-offs

- [A caller passes a hostile `allowed_roots:`] → it is application code, equivalent to that code
  reading the file itself; the request cannot influence it (D2, pinned by spec).
- [Adding the private root lets a private file be copied into public media] → that is the
  existing, intended crop/publish flow for private media, performed by an authorized user; the
  content scan still runs for private sources (D4), unlike for already-public ones.
- [`animate` could gain a future scripting surface] → any such vector would arrive as an
  attribute, and the `on*` rule is element-agnostic; `script`/`foreignObject`/`handler` remain
  banned outright.
- [Someone reads the re-scan exemption as "stored files are trusted"] → it is scoped to the public
  root and documented as an exposure argument, not a trust argument.

## Migration Plan

No schema or data changes. Purely additive for callers: existing `upload_file`/`cama_tmp_upload`
calls behave identically, since `allowed_roots:` defaults to empty.

## Open Questions

None for this change. The HTML-upload question (server-side extension policy, `params[:formats]`
as a narrowing filter rather than the authority, response-side `Content-Disposition`/`nosniff`,
and optionally a separate media origin) is deferred to a follow-up.
