# Design

## D1. A blank parsed host is not proof of same-origin

`safe_redirect_url` trusted `URI#host.blank?` as "relative, therefore safe" and returned the string
unchanged. But several destinations parse to a blank host and still leave the origin in a browser:

- a scheme-only form — `https:evil.com`, `javascript:alert(...)` (`URI#scheme` present, host blank);
- a protocol-relative or backslash form — `///evil.com`, `/\evil.com` (and `\evil.com`, which `URI.parse`
  rejects outright), plus the `%2f`/`%5c` percent-encodings a browser or the Rails backstop decodes.

The fix keeps the host-present branch as-is (same-host only, emitted in canonical case) and replaces the
"host blank ⇒ return unchanged" line with a positive allow rule: a host-blank destination is followed only
when it has no scheme and begins with exactly one `/` followed by a normal path character
(`%r{\A/(?:[/\\]|%2f|%5c)}i` is the reject set). Everything else falls back to the flow's safe default —
never an error, never an off-host `Location`. Backslash-led forms already raise `URI::InvalidURIError` and
are caught by the existing rescue.

## D2. The explicit redirect_url argument gets the same guard

The capability already states the policy applies to "every session flow that consumes `return_to`", but
`login_user`'s explicit `redirect_url` argument bypassed it — it was passed straight to `redirect_to`. That
argument is caller-controlled in practice: core `after_login` hooks and downstream plugins
(camaleon-download, camaleon-ecommerce) set it from a `return_to`/referer value. Routing it through
`safe_redirect_url` (falling back to the dashboard) closes the post-login open redirect for those callers
from one place in core, and leaves the internal callers that pass a fixed local path
(`session_switch_user`, `cama_register_user`) working unchanged.

## D3. Interaction with Rails' open-redirect backstop

The app runs with Rails' `raise_on_open_redirects` default (on), which raised a 500 when the old
`safe_redirect_url` leaked a bad destination into `redirect_to`. Returning only destinations that are
genuinely same-origin means `redirect_to` never receives an off-host value from these flows, so the fix
turns those 500s into a clean fallback to the safe default — and the guard still holds on the Rails 6.1
floor and on installs that disable the backstop (where the leak was a live off-site redirect).
