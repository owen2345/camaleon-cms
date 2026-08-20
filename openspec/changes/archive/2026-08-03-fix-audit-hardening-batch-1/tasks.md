# Tasks: fix-audit-hardening-batch-1

Implementation landed on `fix/regression-audit-hardening-batch-1` (PR #1223); every fix was
demonstrated red→green by a spec reproducing the regression before the fix was applied.

## 1. Boot and plugin registration

- [x] 1.1 Guard the `MediaSecurityHeaders` insertion on `public_file_server.enabled` in
  `lib/camaleon_cms/engine.rb`; add the subprocess boot spec and the
  `CAMA_TEST_DISABLE_FILE_SERVER` test-env hook
- [x] 1.2 Drop nils in `PluginRoutes.all_helpers`/`site_plugin_helpers`
  (`lib/plugin_routes.rb`) and cover helper-less apps in `spec/lib/plugin_routes_spec.rb`

## 2. Controller helper surface and frontend rendering

- [x] 2.1 Include `CamaleonCms::CamaleonHelper` in `CamaleonController` ahead of the runtime
  concerns; cover `GET /search` in `spec/requests/frontend/search_spec.rb`
- [x] 2.2 Downcase the search query before the SQL pattern and honor hook-supplied empty result
  sets in `FrontendController#search`; cover with the non-ASCII case-folding example
- [x] 2.3 Fix the inverted `skip_config` guard in `cama_sitemap_cats_generator`, pass `@r`
  through from the default-theme template, and cover `/sitemap.html` in
  `spec/requests/frontend/sitemap_spec.rb`

## 3. Case-insensitive credential lookups

- [x] 3.1 Restore `find_by_username`/`find_by_email` (with `Rails/DynamicFindBy` pins) in the
  login action, the password-reset lookup, `SessionHelper#login_user_with_password`, and
  `SiteDecorator#the_user`
- [x] 3.2 Cover mixed-case sign-in and reset in `spec/features/admin/session_spec.rb`, the
  decorator lookup in `spec/decorators/site_decorator_spec.rb`, and rewrite the stub-based
  `login_user_with_password` example against real records

## 4. Verification and close-out

- [x] 4.1 Full gates green: `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Archive this change on the branch as part of PR #1223
