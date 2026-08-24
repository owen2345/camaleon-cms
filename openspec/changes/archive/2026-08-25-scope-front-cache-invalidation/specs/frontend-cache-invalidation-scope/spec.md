# frontend-cache-invalidation-scope Delta

## Purpose

The front_cache plugin shares `Rails.cache` with the rest of the application — including security
counters such as the login brute-force throttle. Invalidating front_cache's page cache must therefore
be scoped to the entries front_cache itself owns and must never empty the shared store.

## ADDED Requirements

### Requirement: Invalidating the page cache never clears the shared cache store

front_cache invalidation (triggered by any content-changing request — POST, PUT, PATCH or
DELETE — while the plugin is active, by the admin "Clean cache" action, or by the on-restart
refresh) SHALL NOT clear the shared `Rails.cache`
store and SHALL NOT delete any cache entry it does not own. Entries written by other components —
for example the per-IP login brute-force counter — SHALL survive front_cache invalidation unchanged,
including their remaining TTL semantics.

#### Scenario: A security counter survives a POST-triggered invalidation

- **WHEN** an unrelated cache counter (such as a per-IP failed-login counter) holds a value and a
  POST request triggers front_cache invalidation
- **THEN** the counter still holds the same value in the underlying store

#### Scenario: A DELETE retires the cache like a POST

- **WHEN** a DELETE request (for example a permanent post deletion) runs while the plugin is active
- **THEN** the site's cached pages are invalidated

#### Scenario: A counter accumulates across successive POST lifecycles

- **WHEN** a per-request counter is incremented once per request across two request lifecycles that
  each also trigger front_cache invalidation
- **THEN** the underlying store reads 2 after the second lifecycle

### Requirement: Invalidation still retires all of the site's cached pages

Invalidation SHALL make every page previously cached for the site unservable from the cache
(subsequent lookups miss and pages are re-cached fresh), regardless of which cache store backs
`Rails.cache`. This SHALL be achieved by a mechanism available on every store (a version compared
on every page-cache read), not by an operation only some stores support.

#### Scenario: A cached page is not served after invalidation

- **WHEN** a page body is cached for the site and front_cache invalidation runs
- **THEN** a subsequent lookup for that page misses the cache

#### Scenario: Invalidation works on a store that cannot enumerate keys

- **WHEN** the configured cache store does not support matcher-based deletion
- **THEN** invalidation neither raises nor clears the store, and previously cached pages still miss

### Requirement: Stored page entries are bounded and purged only site-scoped, off the request path

Stored page entries SHALL be bounded at one entry per cached URL: re-caching a page after an
invalidation SHALL overwrite the retired entry in place rather than accumulating an entry per
invalidation. A physical purge of stored entries SHALL run only on the explicit admin clean action —
never on the per-request invalidation path, which SHALL perform no store enumeration. The purge
SHALL delete only entries under front_cache's own distinctive, site-scoped key namespace (including
when the store is configured with a `namespace:` option), SHALL NOT delete entries of other sites or
of other cache users, and SHALL be best-effort: a store that cannot enumerate keys leaves entries to
its own expiry/eviction without breaking the admin action.

#### Scenario: A re-cached page overwrites its retired entry

- **WHEN** a page is cached, the site invalidates, and the page is cached again
- **THEN** the store holds a single entry for that page, containing only the new body

#### Scenario: The admin clean action purges the site's stored pages

- **WHEN** the admin clean action runs on a store that supports matcher-based deletion — with or
  without a configured store `namespace:`
- **THEN** the site's stored page entries are removed from the underlying store

#### Scenario: Another site's page cache is untouched

- **WHEN** two sites (including sites whose ids share a digit prefix, such as 1 and 11) have cached
  pages and one site invalidates or purges
- **THEN** the other site's cached page entries remain in the store

#### Scenario: A store error during the purge does not break the admin action

- **WHEN** the store raises on matcher-based deletion (unsupported or store-specific errors)
- **THEN** the purge is skipped with a logged warning and the action completes; the version bump has
  already retired the pages
