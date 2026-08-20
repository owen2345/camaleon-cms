## 1. M15 — admin login-page locale (commit 1)

- [x] 1.1 New `spec/requests/admin/sessions_locale_spec.rb`: site languages `[es, en]` → login
      page renders the Spanish `log_in` label (red on the unfixed controller); `?locale=en`
      honored; `?locale=` not offered by the site falls back without a server error; frontend
      `session[:cama_current_language]` does not leak in.
- [x] 1.2 `SessionsController#before_hook_session`: resolve `I18n.locale` from
      `current_site.get_languages` with the availability-guarded `?locale=` override; keep the
      frontend-session separation comment accurate.
- [x] 1.3 Spec file green; `bin/rubocop` clean on touched files; commit M15.

## 2. M17 — case-insensitive same-host return_to (commit 2)

- [x] 2.1 Extend `spec/requests/security/open_redirect_session_spec.rb`: mixed-case same-host
      `return_to` is followed on login-when-signed-in, the post-login cookie, and logout (red on
      the unfixed helper — currently falls back); cross-host still falls back (existing
      negatives stay green).
- [x] 2.2 `SessionHelper#safe_redirect_url`: `casecmp?` host comparison; state the same-host-only
      (no multisite cross-site) contract in the method comment.
- [x] 2.3 Spec file green; `bin/rubocop` clean on touched files; commit M17.

## 3. M14 — non-scalar user_id degrades to the route target (commit 3)

- [x] 3.1 Extend `spec/requests/admin/users_controller/member_route_target_resolution_spec.rb`:
      admin `PATCH /admin/users/A?user_id[]=B` updates A with no server error (red: 500 via
      `find(Array)`); non-admin self-edit with `?user_id[]=` succeeds on the path target (red:
      wrongly denied today); scalar-injection scenarios stay green.
- [x] 3.2 `UsersController#user_id_param`: only a scalar (String) `params[:user_id]`
      participates; otherwise resolve from `params[:id]`.
- [x] 3.3 Spec file green; `bin/rubocop` clean on touched files; commit M14.

## 4. Verification and CI parity

- [x] 4.1 Full `bin/rspec` suite green.
- [x] 4.2 `bin/rubocop` clean, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 5. OpenSpec + PR protocol

- [x] 5.1 `openspec validate fix-session-locale-and-redirects --strict` passes; archive the
      change on-branch, syncing the two new capabilities and the `user-target-resolution`
      amendment; commit the archived change (no `[skip ci]` — it heads the first push).
- [x] 5.2 Push branch, open the PR (What and Why + User-Visible Impact; no files-changed/test
      counts/logs/SHAs), first push runs CI.
- [x] 5.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push; record
      the `cama_site_check_existence` triage outcome for follow-up.

## 6. Post-review hardening (same branch, after archive)

- [x] 6.1 Admin: scalar guard for `?locale=` in `set_login_locale` (red-first spec in
      `sessions_locale_spec.rb`); non-scalar scenario added to `admin-login-locale`.
- [x] 6.2 Frontend: scalar guards for `?locale=` / `?cama_set_language=` in `init_frontent`
      (red-first specs in new `spec/requests/frontend_locale_spec.rb`).
- [x] 6.3 Frontend: register theme lookup prefixes before the locale availability gate and
      reset the rejected locale, so unoffered locales render the site's 404 instead of a
      `MissingTemplate` 500 (red-first spec); `frontend-locale-resolution` capability added.
- [x] 6.4 Full gauntlet re-run (rspec, rubocop, brakeman, zeitwerk); changelog entry extended;
      PR description updated.
