# Design: fix-audit-hardening-batch-1

## Context

A five-stream regression audit of `2.9.2..master` (report kept locally as
`REGRESSION-AUDIT-2026-08-03.md`, gitignored) confirmed twelve high-severity regressions. The six
addressed here are one-line-to-small restorations of 2.9.2 behavior; the remaining six (STI data
integrity, user-deletion cascades, upload false positives, path-root restrictions) are larger and
deferred to follow-up changes. Implementation landed on `fix/regression-audit-hardening-batch-1`
(PR #1223) before this change was written, so the artifacts capture completed work; every fix was
demonstrated red→green by a spec that reproduced the regression first.

## Goals / Non-Goals

**Goals:**

- Pin the six restored behaviors as OpenSpec requirements so they cannot regress silently again.
- Keep each fix byte-minimal and faithful to the 2.9.2 contract.

**Non-Goals:**

- The other six audit highs (H7–H12) and all medium findings — follow-up changes.
- Restoring the full 2.9.2 controller include list (`ShortCodeHelper`, `HtmlHelper`,
  `UserRolesHelper` remain view-only); only `CamaleonHelper` is restored, which covers the
  demonstrated crashes.

## Decisions

- **D1 — Conditional middleware insertion over `rescue`:** the engine checks
  `app.config.public_file_server.enabled` and either inserts before `ActionDispatch::Static` or
  appends the middleware (still ahead of the engine's own static handler, since proxy operations
  replay in call order). A `rescue` around `insert_before` would mask genuine stack errors; the
  config flag is exactly the condition Rails itself uses to add the middleware.
- **D2 — `.compact` at the producer, not the consumer:** nils are dropped inside
  `PluginRoutes.all_helpers`/`site_plugin_helpers` rather than guarded at
  `CamaleonController`'s `include`, because `site_plugin_helpers` is also a public API whose
  callers should never see nils.
- **D3 — Restore `CamaleonHelper` only, included before the runtime concerns:** the include sits
  above the concern includes so any future concern method of the same name would take precedence.
  The wider 2.9.2 include list is not restored wholesale because the runtime concerns duplicate
  parts of those helpers (e.g. `RuntimeShortcodeThemeConcern` vs `ShortCodeHelper`) and the
  include order would silently swap implementations — that cleanup needs its own change.
- **D4 — Merge semantics for the sitemap guard:** `skip_config` is normalized to a Hash and then
  merged over the defaults, and the shipped template passes `@r` (the `on_render_sitemap` hook
  config) through — restoring the 2.9.2 skip contract while keeping the newer explicit-argument
  interface for external callers.
- **D5 — Keep the custom finders' names and pin the cop:** `find_by_username`/`find_by_email`
  look like dynamic finders to `Rails/DynamicFindBy` but are real class methods; renaming them
  would break external callers, so the call sites carry `rubocop:disable` pins exactly like the
  existing `find_by_slug` sites.
- **D6 — Unit spec for the boot regression runs the dummy app in a subprocess** with
  `CAMA_TEST_DISABLE_FILE_SERVER=1` (a test-env hook), because the crash only exists in a
  middleware configuration the in-process test app never has.

## Risks / Trade-offs

- [Appended middleware position differs from the enabled-case position] → In the disabled case
  no Rails static middleware serves `/media/` anyway; the headers middleware still wraps
  whatever reaches the router, and real static serving happens in the web server, where these
  headers must be configured at the proxy (unchanged from 2.9.2, which had no middleware at all).
- [The stub-based `login_user_with_password` spec was rewritten against real records] → the old
  stub pinned the exact-match implementation and would have re-broken on any internal change;
  real records pin the observable contract instead.
- [`is_a?(Hash)` + merge accepts hook configs carrying extra keys] → intended: `@r` holds the
  full sitemap render config; the generator reads only the two skip lists.

## Migration Plan

None required — every change restores prior behavior; no data or config migration.

## Open Questions

None. Follow-up scope for the remaining audit findings is tracked in the audit report, not here.
