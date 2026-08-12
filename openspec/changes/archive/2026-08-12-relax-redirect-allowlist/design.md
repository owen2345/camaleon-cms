# Design

## D1. Vet the destination, don't trust the hook

Following whatever the hook set would re-open the open redirect: a plugin that sets
`r[:redirect_to] = params[:return_url]` (a common shape) launders attacker-controlled input straight into
`redirect_to`. So the relaxation is expressed as *trust decisions about hosts*, not trust of URLs:

- an **allowlist** (`redirect_allowed_hosts` option + `safe_redirect_hosts` hook) — the admin or plugin
  declares which off-site hosts are legitimate, and core enforces that only those hosts are reachable, no
  matter how the URL was computed. SSO IdP endpoints and payment checkout hosts are fixed, so an allowlist
  covers them.
- an explicit **opt-in** (`allow_external`) for the rare fully-dynamic destination a plugin constructs and
  vouches for. It is available only on server-set redirect arguments, never on a caller-controlled
  `return_to`, so request input can never reach it.

Both are empty/false by default: the strict same-host policy holds until something is explicitly trusted.

## D2. Scheme is checked before any host decision

The `http`/`https`-only check moved ahead of the same-host comparison, so it also gates the allowlist and
opt-in branches. `javascript://allowlisted-host/...` is rejected even though the host is trusted — a
trusted host must not become a vector for a scheme that would execute if the value ever reached an
`href`/JS sink.

## D3. allow_other_host and the Rails version floor

The app runs Rails' `raise_on_open_redirects` (on by default from 7.0), which raises on an off-host
`redirect_to`. A vetted off-site destination is therefore emitted with `allow_other_host: true`, added
only when the target is genuinely off-host so same-host redirects keep the backstop as a second layer.
`allow_other_host` is a 7.0+ option; the gem supports Rails 6.1, which has no backstop, so the marker is
gated behind `Rails::VERSION::MAJOR >= 7` and simply omitted there.

## D4. One redirect path

`cama_safe_redirect(url, fallback, allow_external:)` centralizes vet + fallback + `allow_other_host`, so
the four session redirect sites (login while signed in, post-login cookie/arg, logout, registration) share
one implementation and one place to reason about the policy.

## D5. Allowlist source and shape

`cama_redirect_allowed_hosts` is consulted only for an off-host destination (same-host/relative redirects
skip it entirely). It reads the `redirect_allowed_hosts` option as a comma-separated list and runs the
`safe_redirect_hosts` hook with `r = { hosts: [...] }` for plugins to append to, then matches the target
host case-insensitively. Exact host match only — no wildcards — keeping the trusted set unambiguous.
