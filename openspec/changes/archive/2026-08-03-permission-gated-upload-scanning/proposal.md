# Proposal: permission-gated-upload-scanning

## Why

Whether an upload is scanned was decided by a filesystem predicate. #1226 exempted any source
already under `Rails.public_path` from re-scanning, on the reasoning that those bytes are already
served. That holds for the *bytes* but not for the *operation*: the exemption keyed on the source
path, while the scan ruleset and the `Content-Type` the web server will serve both key on the
**output filename**, which the caller supplies as `params[:name]`.

`content_unsafe?` sends `.svg` to `SvgContentChecker` and everything else to
`ContentSecurity::BLOCKED_ELEMENTS`, and those rulesets disagreed. A user holding only
`manage :media` could upload an SVG carrying a `<form>`, re-crop it with `name=phish.html`, and
have the identical bytes served as `text/html` from the site origin, unscanned. Nothing else
stopped it: `formats` defaults to `'*'` and arrives from params, and `MediaSecurityHeaders` covers
only `.svg` — and does not run where the web server serves `public/` directly.

"May this content skip the scan?" is an authorization question. Camaleon already answers the
equivalent question for post content and for contact forms with a role permission that only
administrators hold by default. Uploads should work the same way.

## What Changes

- A new `media_unfiltered_upload` manager permission joins `UserRole::ROLES[:manager]`. Only
  administrators hold it by default — they satisfy it through `can :manage, :all`, and no
  non-admin role is seeded with any manager meta. Operators may grant it explicitly, exactly as
  they can for the two existing unfiltered-content permissions.
- The upload content scan is gated on that permission instead of on the source path. A user who
  holds it uploads without scanning; a user who does not has **every** upload scanned, whatever
  the source — including files already published under `Rails.public_path`. The path-based
  exemption and its `cama_source_already_public?` predicate are removed.
- The check fails closed. When there is no request user or site — background jobs, rake tasks, the
  console — the upload is scanned, matching how `Post#trusted_for_unfiltered_html?` behaves.
- `form`, `meta`, `base`, `style` and `link` join `SvgContentChecker::BANNED_TAGS`. These are
  legitimate SVG elements but live markup the moment the file is served as, or embedded in, HTML;
  since only untrusted uploads are scanned at all, the checker can ban them unconditionally.
- Rejection stays rejection. Nothing is sanitized, escaped or rewritten — an upload that trips a
  rule is refused with `Potentially malicious content found!`, as today.

## Capabilities

### New Capabilities

- `unfiltered-upload-permission`: the `media_unfiltered_upload` role permission, who holds it by
  default, and the fail-closed rule for contexts with no request user.

### Modified Capabilities

- `upload-content-security`: scanning is gated on the permission rather than on the source path;
  the already-published exemption is withdrawn.
- `svg-upload-sanitization`: `form`, `meta`, `base`, `style` and `link` become banned elements.

## Impact

- `app/models/camaleon_cms/user_role.rb` (the new manager permission)
- `lib/camaleon_cms/uploader_content_security.rb` (the trust predicate)
- `lib/camaleon_cms/uploader_pipeline.rb` (gate the three scan sites, drop the exemption)
- `lib/camaleon_cms/uploader_path_security.rb` (remove `cama_source_already_public?`)
- `lib/camaleon_cms/svg_content_checker.rb` (banned tags)
- Specs under `spec/lib/camaleon_cms/`, `spec/lib/svg_content_checker_spec.rb`,
  `spec/models/`, and a request spec reproducing the rename bypass end to end

**Behaviour withdrawn on purpose:** re-cropping an already-stored file is scanned again for users
without the permission. #1226 removed that scan to stop legitimate re-crops being rejected; the
narrower fix is the permission, not a filesystem predicate that a caller-supplied filename can
walk through.
