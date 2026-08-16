# Design

## Eager-loading metas rather than warming a bespoke cache

`get_meta` already reads from the `metas` association when it is loaded (`metas.loaded?`), so
`Site.includes(:metas)` is enough to move every per-site option/language/theme read into memory with
no change to the readers. Loading all metas for all sites is a one-time route-draw cost and is far
cheaper than one `_default` options query per site.

## Short-circuiting the enabled-plugin query on an empty site list

The previous `get_sites.flat_map { |s| s.plugins.active.pluck(:slug) }` issued no query when there
were no sites (an empty `flat_map`). During early boot `get_sites` rescues to `[]` before the DB is
ready; an unconditional `pluck` would still execute SQL there and abort route loading. The
replacement keeps that boot-safety by returning `[]` when there are no site ids, and otherwise runs a
single `parent_id IN (...)` query.

## Scoping the eager draw to non-`eager_load` (development)

Production sets `config.eager_load = true`, which draws the route table during boot — there is no
first-request race there, so a second full multi-site redraw would only add boot cost. The dev/test
window where routes are drawn lazily on the first request is the only place the race exists, so the
eager draw runs only there. It is additionally guarded by `db_installed?` and rescued so it can never
abort boot (migrations, asset precompile, a fresh install before `db:create`).

## `no-store` on admin responses vs. the security remedy rule

The remedy rule forbids response headers as a control over what *untrusted, stored content* does in
the browser — such content is judged at save time and served verbatim. `no-store` here is unrelated:
it applies to *admin HTML responses* (trusted, per-user, dynamic pages) purely as caching hygiene, so
a stale admin render is never reused. It constrains no stored content and no untrusted author, so it
sits outside that rule.

## Refinements from code review

A max-effort review of the branch surfaced several issues in the first cut; the fixes below landed as
follow-up commits on the same PR.

- **Where the boot draw runs.** `config.after_initialize` runs before Rails' `:add_internal_routes`
  and the host app's own `after_initialize`, so drawing there built an incomplete table that only
  survived because `reload_routes!` leaves the table marked unloaded for the first request to redraw
  — a double draw every boot that never actually pre-empted the first-request draw. The draw now runs
  from an initializer anchored `after: :set_routes_reloader_hook` (declared last among the engine
  initializers so its cross-cutting `after:` does not reorder the middleware-mutating initializer past
  `:build_middleware_stack`) and calls `routes_reloader.execute_unless_loaded`, which draws once and
  leaves the table loaded so the first request serves it directly.
- **post_types was still an N+1.** Only metas and plugin slugs were batched; the frontend post-type
  route loop still issued one `post_types` query per site. `get_sites` now eager-loads `:post_types`
  too and the loop maps in memory, so the whole draw is a fixed query count regardless of site count.
- **Full metas load is deliberate.** A scoped metas preload would be cheaper, but `get_meta`'s loaded
  branch reads a key absent from the loaded records as unset, so preloading only the route-draw keys
  would make every other site meta read return its default. The bounded full load is the safe trade.
- **Empty results are not cached as a hit.** `all_enabled_plugins`/`all_enabled_themes`/`all_locales`
  returned `[]`/`''` on a not-ready DB and cached it; because those are truthy, the empty value stuck
  until an explicit reload (an empty `all_locales` also degraded the frontend locale constraint to
  `//`). They now recompute on an empty result, matching the self-healing filesystem-backed caches.
- **DB-readiness gated once; batched query is subquery-shaped.** The per-call `site_ids.empty?` check
  became one `return [] if get_sites.empty?` guard, and the enabled-plugin lookup uses a
  `parent_id IN (SELECT id …)` subquery so it carries no IN-list bind cap on very large installs.
- **Boot-safety rescue narrowed.** The draw now rescues only `ActiveRecord::ActiveRecordError`, so
  DB-unavailability still fails safe but a genuine route error surfaces instead of being hidden.
- **Skipped during `db:` Rake tasks; otherwise process-agnostic.** A `db:` task (`db:migrate`,
  `db:schema:load`, …) boots against a schema that is mid-change, so the draw is skipped there —
  detected via `Rake.application.top_level_tasks` (populated for both `rails db:*` and `rake db:*`;
  absent in the server/console/runner). `ARGV` is not usable this early, since `rails` consumes the
  command name before initializers run. The draw still runs in every other non-`eager_load` process
  (server, console, workers): Rails exposes no reliable, version-stable "is this the server?" signal
  across the 6.1–8.1 range, and the draw is otherwise bounded and safe (one guarded, rescued,
  idempotent draw over long-stable columns), so gating it further is not worth the fragility.
