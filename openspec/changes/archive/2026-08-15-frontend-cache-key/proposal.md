# Give front_cache a lossless cache key (Low)

## Why

The `front_cache` plugin keyed its page cache on `uri.parameterize`, which lowercases the URL and
collapses every run of non-alphanumerics to a single `-`. Distinct cacheable URLs therefore map to
the same key (`/a/b` and `/a-b`, `/Page` and `/page`, …), so a visitor to one can be served the
cached body of another — a cache-poisoning / wrong-content Low. Separately, admin-configured path
patterns were compiled with `Regexp.new` on every request with no rescue, so a malformed pattern
raised (500) and every request re-compiled them. Audit Low.

### Triage verdict: legit

Reproduced in `spec/apps/plugins/front_cache/cache_key_integrity_spec.rb`: `/a/b` and `/a-b`
produced the same parameterized key, and an invalid path pattern raised `RegexpError`.

## What Changes

- The cache key is now `Digest::SHA256.hexdigest(uri)` — lossless, so distinct URLs never collide.
- Path patterns are compiled once per request (memoized) and malformed patterns are skipped rather
  than raising.

## Notes for upgraders

- Existing cached pages are keyed under the old scheme; after upgrade they simply miss once and
  regenerate under the new key. No action needed.
- A hard ReDoS timeout on admin path patterns is not added here — `Regexp.timeout` requires Ruby
  3.2+, below the gem's `>= 3.0` floor; the patterns remain admin-only configuration.
