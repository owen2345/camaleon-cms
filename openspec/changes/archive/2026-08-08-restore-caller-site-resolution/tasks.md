# Tasks: restore-caller-site-resolution

## 1. Reproduce

- [x] 1.1 Add `spec/helpers/camaleon_cms/site_helper_spec.rb`: with `PluginRoutes.get_sites` stubbed to a
      multisite size and `CurrentRequest.site` blank, a caller-set `@current_site` and no request must
      resolve without raising; confirm it fails on master with `NameError`.

## 2. Fix

- [x] 2.1 In `SiteHelper#current_site`, restore the `@current_site` branch after `$current_site` and
      before `CurrentRequest.site`, writing through to `CurrentRequest.site`.
- [x] 2.2 Cover the precedence (`@current_site` over a memoized `CurrentRequest.site`) and the
      no-request mailer reproducer (`HtmlMailer.sender(..., current_site:)` builds without raising).

## 3. Ship

- [x] 3.1 `bin/rspec` (new spec + `spec/mailers`), `bin/rubocop` on touched files, `bin/brakeman --no-pager`,
      `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 Archive on the branch (syncs `site-resolution-order` into `openspec/specs/`).
- [x] 3.3 Commit, push, open the PR, then add the changelog entry referencing it.
