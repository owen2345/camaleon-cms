## 1. Branch

- [x] 1.1 Create branch `fix/admin-title-double-escaping` off the latest `master` and announce it — branched from `master` at `c27dbcc4`
- [x] 1.2 Confirm the defect in rendered HTML before changing anything — ✅ `settings/site.html.erb:6` and `posts/form.html.erb:12` both emit `Ben &amp;amp; Jerry&amp;#39;s`; `posts/index.html.erb:54` renders correctly, confirming argument-passing is the working shape
- [x] 1.3 Confirm the SEO surface is **not** affected — ✅ `display_meta_tags` round-trips through `strip_tags`, absorbing the extra layer; `<title>` renders `Ben & Jerry's <Best> Cakes`. No fix, no theme-author contract change

## 2. Reproduce first

- [ ] 2.1 Add `spec/requests/admin/title_escaping_spec.rb` with a shared example asserting both directions on a page: rendered text contains the literal `Ben & Jerry's <b>x</b>`, **and** `doc.css('b')` finds no injected element
- [ ] 2.2 Apply it to the site settings page and the post edit form — the two verified sites
- [ ] 2.3 Extend to the categories index, tags index, sites form, and the custom fields category select
- [ ] 2.4 Add a case for the already-correct posts index, asserting it stays correct
- [ ] 2.5 Add a helper spec for `cama_pluralize_text` covering safe input, unsafe input, and `nil`
- [ ] 2.6 Add a case asserting the categories-index action-button `title` attribute contains no `&Amp;` (blocker 2)
- [ ] 2.7 Confirm the new examples fail against unmodified `master`, except 2.4 which must pass both before and after

## 3. Unblock composition

- [ ] 3.1 Change `cama_pluralize_text` to propagate its input's safeness, never to add it — `design.md` D2
- [ ] 3.2 Confirm 2.5 passes and no existing caller of `cama_pluralize_text` changes behaviour for unsafe input

## 4. Fix the composition sites

- [ ] 4.1 `admin/posts/form.html.erb:12` — `safe_join`
- [ ] 4.2 `admin/settings/site.html.erb:6` — `safe_join`
- [ ] 4.3 `admin/settings/sites/form.html.erb:8` — `safe_join` inside the ternary
- [ ] 4.4 `admin/categories/index.html.erb:15` — `safe_join`
- [ ] 4.5 `admin/post_tags/index.html.erb:6` — `safe_join`, now that 3.1 keeps the flag
- [ ] 4.6 `admin/settings/custom_fields/_render_category_simple.html.erb:5` — `safe_join` for both the option text and the `data-help` attribute
- [ ] 4.7 `admin/post_tags/index.html.erb:40` — `title:` attribute, `safe_join`
- [ ] 4.8 `admin/categories/index.html.erb:42` — `title:` attribute; titleize the unescaped translated value per `design.md` D3, not the escaped one
- [ ] 4.9 Leave `admin/posts/index.html.erb:10` alone — interpolation into a `raw` sink, renders correctly, not worth the churn
- [ ] 4.10 Introduce no new `raw` or `html_safe` while doing the above; the section 2 specs fail if a fix takes that route

## 5. Verification

- [ ] 5.1 Confirm every spec from section 2 passes
- [ ] 5.2 `bin/rspec` — full suite green, with particular attention to existing admin categories, tags, custom fields, and settings specs
- [ ] 5.3 `bin/rubocop -A` on touched files only
- [ ] 5.4 `bin/brakeman --no-pager` — no new warnings, and confirm no new `Rails/OutputSafety` disables were added
- [ ] 5.5 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 6. Changelog and archive

- [ ] 6.1 Add a `## Unreleased` **Fix** entry: admin headings displayed raw entities for names containing `&`, `'`, `<` or `>`; the cause is an escaped `SafeBuffer` interpolated into a plain string ahead of an ERB sink
- [ ] 6.2 Add an upgrader note for `cama_pluralize_text` — it now returns a `SafeBuffer` for a `SafeBuffer` input, propagating safeness it was given and never adding it
- [ ] 6.3 Note explicitly that `the_title` still escapes and that the SEO surface was checked and is unaffected, so theme authors need change nothing
- [ ] 6.4 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
