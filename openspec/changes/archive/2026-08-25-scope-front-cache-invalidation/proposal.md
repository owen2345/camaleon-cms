## Why

The bundled front_cache plugin hooks `front_cache_post_requests` on both `front_before_load` and
`admin_before_load`, and on every POST/PATCH it calls `front_cache_clean`, which in its default mode
runs `Rails.cache.clear` — wiping the entire cache store, not just front_cache's own page entries.
Every Rails.cache-based counter in core and other plugins is destroyed on each such POST while
front_cache is active. This defeats core's per-IP login brute-force counter
(`login-brute-force-protection`) — not via the login POST itself, which runs no front_cache hook
(SessionsController inherits CamaleonController and fires only `session_before_load`), but via any
interleaved POST: an attacker resets their own counter with one cheap unauthenticated frontend POST
(comment, contact form) between login attempts, silently defeating the captcha gate and hard
lockout. It likewise defeats the cama_contact_form submission throttle. The opt-in
`invalidate_only` mode (version-counter folded into cache keys) already avoids the nuke and is the
store-agnostic invalidation path.

## What Changes

- `front_cache_clean` stops calling `Rails.cache.clear`. Invalidation always uses the existing
  `cache_counter` version bump (the current `invalidate_only` behavior), so entries owned by other
  cache users — throttle counters, other plugins — survive front_cache invalidation.
- To preserve the disk/memory reclamation the global clear used to provide, `front_cache_clean`
  additionally deletes the site's own `pages/<counter>/<site_id>/…` entries via
  `Rails.cache.delete_matched`, best-effort: stores that cannot enumerate keys with a Regexp matcher
  (MemCacheStore raises NotImplementedError, RedisCacheStore accepts only glob strings) are rescued
  and rely on the version bump plus the store's own eviction.
- **BREAKING** (settings UI only): the `invalidate_only` checkbox is removed from the plugin's
  settings screen — invalidate-only is now the only behavior, so the option no longer selects
  anything. A stored `invalidate_only` value is ignored harmlessly.
- Non-goals: the invalidation *trigger* (every POST/PATCH invalidates all cached pages) is
  unchanged; page-cache key derivation (`frontend-cache-key-integrity`) is unchanged; no TTLs are
  added to page entries.

## Capabilities

### New Capabilities

- `frontend-cache-invalidation-scope`: front_cache invalidation must be scoped to front_cache's own
  page-cache entries — it must never clear the shared `Rails.cache` store or delete entries it does
  not own (other sites' page caches included), while still invalidating all of the site's cached
  pages when content may have changed.

### Modified Capabilities

<!-- none: login-brute-force-protection and frontend-cache-key-integrity requirements are unchanged;
     this change restores the environment they assume rather than altering what they require -->

## Impact

- `app/apps/plugins/front_cache/front_cache_helper.rb` (`front_cache_clean`)
- `app/apps/plugins/front_cache/admin_controller.rb` (`save_settings` drops `invalidate_only`)
- `app/apps/plugins/front_cache/views/admin/settings.html.erb` (checkbox removed)
- `app/apps/plugins/front_cache/config/locales/translation.yml` (`invalidate_only` labels removed)
- Restores effectiveness of `login-brute-force-protection` and any other Rails.cache consumers when
  front_cache is active; external callers of the public `front_cache_clean` helper keep the same
  contract (all of the site's cached pages are invalidated).
