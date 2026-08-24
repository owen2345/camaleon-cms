# frontend-cache-invalidation-scope Specification

## Purpose
The front_cache plugin shares `Rails.cache` with the rest of the application — including security
counters such as the login brute-force throttle. Invalidating front_cache's page cache must therefore
be scoped to the entries front_cache itself owns and must never empty the shared store.
## Requirements
### Requirement: Invalidating the page cache never clears the shared cache store

front_cache invalidation (triggered by any POST/PATCH request while the plugin is active, by the
admin "Clean cache" action, or by the on-restart refresh) SHALL NOT clear the shared `Rails.cache`
store and SHALL NOT delete any cache entry it does not own. Entries written by other components —
for example the per-IP login brute-force counter — SHALL survive front_cache invalidation unchanged,
including their remaining TTL semantics.

#### Scenario: A security counter survives a POST-triggered invalidation

- **WHEN** an unrelated cache counter (such as a per-IP failed-login counter) holds a value and a
  POST request triggers front_cache invalidation
- **THEN** the counter still holds the same value in the underlying store

#### Scenario: A counter accumulates across successive POST lifecycles

- **WHEN** a per-request counter is incremented once per request across two request lifecycles that
  each also trigger front_cache invalidation
- **THEN** the underlying store reads 2 after the second lifecycle

### Requirement: Invalidation still retires all of the site's cached pages

Invalidation SHALL make every page previously cached for the site unservable from the cache
(subsequent lookups miss and pages are re-cached fresh), regardless of which cache store backs
`Rails.cache`. This SHALL be achieved by a mechanism available on every store (a version component
folded into the page-cache key), not by an operation only some stores support.

#### Scenario: A cached page is not served after invalidation

- **WHEN** a page body is cached for the site and front_cache invalidation runs
- **THEN** a subsequent lookup for that page misses the cache

#### Scenario: Invalidation works on a store that cannot enumerate keys

- **WHEN** the configured cache store does not support matcher-based deletion
- **THEN** invalidation neither raises nor clears the store, and previously cached pages still miss

### Requirement: Physical cleanup removes only the site's own retired entries

Where the cache store supports matcher-based deletion, invalidation SHALL physically delete the
retired page entries of the invalidating site only — entries belonging to other sites on the same
install, and entries outside front_cache's page namespace, SHALL NOT be deleted. On stores without
that support, retired entries are left to the store's expiry/eviction.

#### Scenario: The site's stale page entries are reclaimed

- **WHEN** front_cache invalidation runs on a store that supports matcher-based deletion
- **THEN** the site's previously cached page entries are removed from the underlying store

#### Scenario: Another site's page cache is untouched

- **WHEN** two sites (including sites whose ids share a digit prefix, such as 1 and 11) have cached
  pages and one site invalidates
- **THEN** the other site's cached page entries remain in the store
