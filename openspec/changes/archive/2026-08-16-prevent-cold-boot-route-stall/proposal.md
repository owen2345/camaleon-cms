# Prevent cold-boot route-draw stall on multi-site installs

## Why

On installs with many sites, the first request after a server (re)start could 404 or render an admin
page half-initialized. Drawing the route table walks every site to read its options, languages and
theme and to collect its enabled plugins — one query per site apiece. On a large multi-site install
(hundreds or thousands of sites) that N+1 takes several seconds, and in development the draw happens
lazily on the first request, so requests are already being served against a route table that is
still being built: an early one 404s (routes not drawn yet), a slightly later one renders but with
the editor JS failing to initialize — a stale render the user then had to reload away.

The stored content was never at risk: the server always renders it, the blank editor was a cold-boot
client-side artifact, and a stale cached admin render could reappear after a restart until a manual
reload.

## What Changes

- **Bounded route drawing.** `PluginRoutes.get_sites` eager-loads each site's metas, so the per-site
  option/language/theme reads route drawing performs hit memory instead of one `_default` options
  query per site. Enabled plugin slugs are collected in a single `parent_id IN (...)` query across
  all sites instead of one query per site. Route drawing no longer scales with the number of sites.
- **Eager draw at boot.** `PluginRoutes.draw_routes_eagerly` draws the table once during boot —
  development only, since production already eager-loads routes at boot — guarded by `db_installed?`
  and rescued, so no request is ever served against a half-built table.
- **Uncacheable admin responses.** Admin responses send `Cache-Control: no-store`, so a stale render
  can never be reused after a restart.

## Notes for upgraders

- No action needed. On a large multi-site install the first request after a restart is now cheap and
  the route table is ready before any request is served; production behaviour is unchanged (routes
  were already drawn at boot there).
- Admin pages are no longer stored by the browser cache. This is correct for per-user dynamic pages
  and has no effect on the frontend or on content delivery.
