## 1. Branch

- [x] 1.1 Create branch `security/escape-breadcrumb-sitemap-hrefs` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict before writing the fix — ✅ legit; `escape_segment`/`escape_path` preserve the single quote, and all three sinks reproduce at the helper level; enumeration in `proposal.md`

## 2. Reproduce first

- [x] 2.1 Add a breadcrumb example to `spec/helpers/camaleon_cms/frontend/nav_menu_helper_spec.rb`: a non-last breadcrumb item whose URL carries `x' onmouseover='alert(document.domain)` must render with the quotes HTML-escaped
- [x] 2.2 Add a sitemap example to `spec/helpers/camaleon_cms/camaleon_helper_spec.rb`: `cama_sitemap_cats_generator` must escape both the post and category `href`
- [x] 2.3 Add `spec/helpers/themes/default/default_helper_spec.rb`: `get_taxonomy` must escape the taxonomy `href`
- [x] 2.4 Confirm every example in 2.1–2.3 fails against unmodified `master` before writing any fix

## 3. Fix the sinks

- [x] 3.1 Escape the interpolated URL in `NavMenuHelper#breadcrumb_draw` with `ERB::Util.html_escape`, keeping the surrounding markup byte-identical
- [x] 3.2 Escape the post URL and the category URL in `CamaleonHelper#cama_sitemap_cats_generator`
- [x] 3.3 Escape the taxonomy URL and the `rel` value in the bundled default theme's `get_taxonomy`, in **both** the gem copy and the `spec/dummy` copy (kept identical by `spec/lib/bundled_theme_helper_sync_spec.rb`)
- [x] 3.4 Leave the interpolated titles untouched — they are already escaped `SafeBuffer`s from `the_title`
- [x] 3.5 Leave slug normalization and the helpers' plain-`String` return unchanged — `design.md` D2/D3
- [x] 3.6 Confirm the specs from section 2 now pass

## 4. Cover the unchanged paths

- [x] 4.1 Run the full `nav_menu_helper` and `camaleon_helper` helper specs and confirm the existing breadcrumb/menu/sitemap examples (benign URLs) are unchanged
- [x] 4.2 Confirm `spec/lib/bundled_theme_helper_sync_spec.rb` stays green (the two default-theme copies remain identical)
- [x] 4.3 Run `spec/requests/frontend/` and `spec/requests/security/` and confirm they stay green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and the frontend/security suites — green
- [x] 5.2 `bin/rubocop` on touched files only — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: the three `href` sinks, the privilege (a contributor stores the slug; it fires for visitors and same-origin admins), and a note that stored malicious slugs now render as inert escaped links
- [x] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
