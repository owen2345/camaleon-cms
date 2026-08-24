# Tasks: scope-front-cache-invalidation

## 1. Reproducing specs (write first, watch them fail on master's behavior)

- [x] 1.1 Add `spec/apps/plugins/front_cache/cache_invalidation_scope_spec.rb` on the harness-class
  pattern, backing `Rails.cache` with a real `ActiveSupport::Cache::MemoryStore`: an unrelated
  counter key survives `front_cache_clean`; a counter incremented once per `with_local_cache`
  lifecycle (each also running `front_cache_post_requests` on a POST) reads 2 in the underlying
  store afterwards.
- [x] 1.2 In the same spec file, cover the preserved contract: a cached page misses after clean
  (version bump); the site's own stale entries are physically deleted; site 11's entries survive
  site 1's clean; a store whose `delete_matched` raises `NotImplementedError`/`ArgumentError`
  neither raises nor loses the version bump; a legacy meta with nil `cache_counter` heals; GET
  requests do not trigger `front_cache_post_requests`.

## 2. Implementation

- [x] 2.1 Rewrite `front_cache_clean` in
  `app/apps/plugins/front_cache/front_cache_helper.rb`: drop the `Rails.cache.clear` branch and the
  `invalidate_only` conditional; always `cache_counter = cache_counter.to_i + 1`; best-effort
  `Rails.cache.delete_matched(%r{\Apages/[^/]*/#{current_site.id}/})` rescuing
  `NotImplementedError, ArgumentError`.
- [x] 2.2 Remove the `invalidate_only` setting: checkbox in
  `app/apps/plugins/front_cache/views/admin/settings.html.erb`, the key in `save_settings`
  (`admin_controller.rb`), and the `invalidate_only` label from every locale in
  `app/apps/plugins/front_cache/config/locales/translation.yml`.

## 3. Verification & bookkeeping

- [x] 3.1 Full CI parity locally: `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 CHANGELOG.md entry (≤500 chars, newest-first) describing the fix and the removed
  `invalidate_only` checkbox.
- [ ] 3.3 `/opsx:verify` the change, then `/opsx:archive` on the branch before merge (archive commit
  is part of the PR).
