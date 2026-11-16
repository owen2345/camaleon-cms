# Tasks

## 1. The lock

- [x] 1.1 Add `spec/lib/camaleon_cms/route_reload_lock_spec.rb`. A reload must wait for a request
  that runs, and a new request must wait for a draw. Make sure that these examples fail with a
  middleware that only calls the app.
- [x] 1.2 Add `CamaleonCms::RouteReloadLock` and put it in the middleware stack (D1, D2).
- [x] 1.3 Take the lock in `PluginRoutes.reload` (D3).
- [x] 1.4 Add the time limit and its example (D4).

## 2. Verification and shipping

- [x] 2.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 2.2 Add the CHANGELOG entry, archive this change on the branch
