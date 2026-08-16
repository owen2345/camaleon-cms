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
