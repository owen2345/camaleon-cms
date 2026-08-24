# Design: scope-front-cache-invalidation

## Context

See proposal.md — Why. Mechanics that shape the design:

- Page-cache keys are `pages/<cache_counter>/<site_id>/<sha256(url)>` (built by
  `front_cache_plugin_get_path`); `cache_counter` lives in the per-site `front_cache_elements` meta,
  so bumping it retires every key of that site at once, on any store, across processes.
- `front_cache_clean` is the single choke point: the POST/PATCH hook (`front_cache_post_requests`,
  wired to both `front_before_load` and `admin_before_load`), the admin "Clean cache" action, and the
  on-restart refresh all call it. Fixing it fixes every trigger.
- `Rails.cache.delete_matched` semantics differ per store: FileStore/MemoryStore accept a Regexp,
  RedisCacheStore accepts only glob Strings (raises ArgumentError on Regexp), MemCacheStore raises
  NotImplementedError, NullStore no-ops. A glob String is unsafe on FileStore/MemoryStore because it
  is interpreted as an unanchored regex (`pages/0/1/*` also matches `pages/0/11/...`).
- The 2017-era reason `Rails.cache.clear` stayed the default was disk reclamation on FileStore
  (the Rails default store): version-bumped stale entries are never read again, and FileStore only
  deletes expired entries on read, so they would accumulate unboundedly.

## Goals / Non-Goals

Goals: the shared store is never cleared; retired page entries are physically reclaimed where the
store can do that safely; behavior is identical on every supported store apart from reclamation.

Non-goals: changing the invalidation trigger granularity (every POST/PATCH still retires all of the
site's pages); per-entry TTLs; tracking individual page keys in a registry (rejected below).

## Decisions

1. **Version bump becomes the only logical invalidation** — `front_cache_clean` always increments
   `cache_counter` (guarded with `.to_i` so a legacy meta without the counter, or the pre-2017 nil
   counter, heals instead of raising) and never resets it to 0. Alternative — keeping two modes with
   the default flipped — rejected: with the clear gone, `invalidate_only` no longer distinguishes
   anything a user could want, and a dead setting is worse than none.

2. **Best-effort physical reclamation via `delete_matched` with an anchored Regexp** scoped to the
   site: `%r{\Apages/[^/]*/<site_id>/}`. `[^/]*` (not `\d+`) also sweeps the legacy nil-counter
   namespace `pages//<site_id>/`, and matching every generation (not just the previous one) makes
   each clean self-healing against orphans from crashes or upgrades. The call is wrapped in
   `rescue NotImplementedError, ArgumentError` so MemCacheStore/RedisCacheStore fall back to the
   version bump plus their own eviction. Alternatives rejected:
   - Registry of written keys + per-key delete (store-agnostic reclamation): read-modify-write races
     on every page write, more state, more code — speculative for a page cache.
   - Glob-string matcher for Redis compatibility: unsafe cross-site matching on FileStore (see
     Context), and Redis deployments normally have eviction; correctness wins over coverage.
   - No reclamation at all: regresses FileStore (the default store) to unbounded growth — the exact
     trade-off that kept the global clear alive since 2017.

3. **Remove the `invalidate_only` setting** (checkbox, `save_settings` key, locale strings in all
   languages). A stored value is simply never read again; `save_settings` rewrites the meta wholesale
   on next save. `preserve_cache_on_restart` keeps its meaning (skip the restart-time clean).

4. **Spec-level reproduction at the unit boundary** — the reproducing specs drive
   `front_cache_clean` / `front_cache_post_requests` on a harness class (the pattern of the existing
   front_cache specs) against a real `ActiveSupport::Cache::MemoryStore`, asserting on the
   underlying store. *Post-review correction:* this decision originally justified the unit boundary
   with "request specs cannot observe cross-request `Rails.cache` (per-request LocalCache)" — that
   premise is false: LocalCache is write-through and flushed per request, and this repo's own
   `spec/requests/security/login_brute_force_throttle_spec.rb` observes the per-IP counter
   accumulate across POSTs in a request spec. The unit harness stands on its own merits (fast,
   store-explicit); request-level coverage of cross-request cache behavior is available when needed.

## Risks / Trade-offs

- [FileStore `delete_matched` walks the whole cache directory on every clean] → strictly cheaper than
  the status quo (`clear` destroys everything and forces global re-caching); the walk is per-POST
  only while the plugin is active, and matches the store's documented cost model.
- [MemCacheStore/RedisCacheStore skip reclamation] → same steady-state as the long-standing
  `invalidate_only` mode; both stores evict under memory pressure. Documented in the spec scenario.
- [Concurrent cleans race on the meta read-modify-write] → pre-existing pattern (unchanged); the
  counter advancing by 1 instead of 2 still retires all live keys.
- [Sites that relied on the implicit "clear everything" side effect] → none can rely on it safely;
  the admin "Clean cache" action still retires and (where supported) deletes all of the site's pages.

## Migration Plan

Ships as a normal gem update; no data migration. Existing cached pages under the current counter are
retired on the first POST after upgrade exactly as before. Rollback = revert the commit (the meta
shape is unchanged; a grown `cache_counter` is valid input to the old code).
