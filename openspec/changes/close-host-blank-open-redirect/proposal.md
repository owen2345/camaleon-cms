## Why

`safe_redirect_url` returned any URL whose *parsed* host was blank unchanged — but a blank host does not
mean same-origin. `return_to=///evil.com` (also `https:evil.com`, `javascript:...`) parses to a blank host
yet a browser follows it off-site, so `/admin/login?return_to=///evil.com` emitted it verbatim as
`Location`. Separately, `login_user`'s explicit `redirect_url` argument — set by `after_login` hooks and
downstream plugins from caller-controlled values — was redirected without the host check the `return_to`
cookie already gets. Together these are the audit's `///evil.com` open-redirect Low (live where the Rails
backstop is disabled) and the cross-cutting `login_user` explicit-arg gap.

### Triage verdict: legit

Reproduced against master (`spec/requests/security/open_redirect_session_spec.rb`): host-blank `return_to`
values and an off-site `after_login` redirect leak to `redirect_to`. Fails without the fix (confirmed by
stashing it).

## What Changes

- `safe_redirect_url` follows a host-blank destination only when it is a genuine same-origin path: one
  leading `/` then a normal path character. A scheme (`https:evil.com`, `javascript:...`), a
  protocol-relative or backslash form (`///evil.com`, `/\evil.com`), and their `%2f`/`%5c` encodings are
  rejected in favour of the flow's safe default. The host-present, same-host case is unchanged (still
  followed, emitted with the host in the request's canonical case).
- `login_user` routes its explicit `redirect_url` argument through `safe_redirect_url`, so a
  caller-controlled destination (from an `after_login` hook or a downstream plugin) gets the same
  open-redirect guard as the `return_to` cookie branch.

## Notes

- One core change closes the audit's `///evil.com` Low and the shared root cause behind the
  camaleon-download `return_to` and camaleon-ecommerce post-login open redirects (both consume core's
  `login_user`). No ecosystem repos are touched here.

## Out of scope

- The deliberate cross-site-`return_to`-unsupported policy on multisite installs is unchanged.
