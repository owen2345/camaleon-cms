## 1. Branch

- [x] 1.1 Create branch `security/fix-contact-form-output-escaping` off `master` in `camaleon-cms`
- [x] 1.2 Create branch `security/fix-output-escaping` off `master` in `owen2345/cama_contact_form` (currently at 0.1.9, tag and `version.rb` aligned)

## 2. Wire the git source so the plugin is testable from here

- [x] 2.1 Add `gem 'cama_contact_form', git: 'https://github.com/owen2345/cama_contact_form', branch: 'security/fix-output-escaping'` to the main `Gemfile`
- [x] 2.2 Add the same line to all five matrix gemfiles: `gemfiles/rails_7_1.gemfile`, `rails_7_2`, `rails_8_0`, `rails_8_1`, `rails_edge` — omitting any one leaves that leg resolving 0.1.0 from RubyGems and failing the new specs
- [x] 2.3 Confirm Bundler resolves in all six (`~> 0.1.0` from the gemspec must still be satisfied by the branch's `version.rb`)

## 3. Reproduce first

- [x] 3.1 `spec/requests/security/contact_form_output_escaping_spec.rb` — unauthenticated visitor, `text` field. Confirmed failing: the input parses as `["id", "required", "type", "value", "autofocus", "onfocus", "name", "class"]`. Written as a request spec, not a feature spec: no JS is needed to prove it and the browser-driven suite is far slower
- [x] 3.2 Same file, `paragraph` field. Confirmed failing: `alert(1)` appears as a parsed `<script>` element in the response
- [x] 3.3 Same file, stored form definition — covers `label`, `field_class`, a `dropdown` option label, and `field_attributes`. All four confirmed failing. The stored value is written directly rather than driven through the admin UI: the access path (`:manage, :plugins`) is established and unchanged by this fix, so the spec targets what the fix actually alters — the rendering
- [x] 3.4 `spec/lib/ext/hash_spec.rb` — 9 examples, 4 failing as intended: `to_attr_format` admits `onfocus` and `y` as live attributes from `{ class: 'x" onfocus=alert(1) y="' }` and treats `\"` as an escape; `to_attr_url_format` mangles a literal backslash and raises `SyntaxError` on backslash-then-quote. Parsed with Nokogiri so assertions describe what the markup means, not which escaper produced it
- [x] 3.5 Confirmed: **17 examples, 11 failures** across both files. The 6 passing examples are the non-regression guards (legitimate input round-trips, ordinary values unescaped, custom separator, `to_attr_url_format` quote handling), which must pass both before and after

## 4. Camaleon-side code (this repo)

- [x] 4.1 Replaced `gsub('"', '\"')` in `to_attr_format` with **`CGI.escapeHTML`**, not `ERB::Util.html_escape`. Verified empirically that the latter is a no-op on an `html_safe` value (`"x\" <a> & q"` came back with its quote intact), which would let such a value still break out. Attribute values are never markup, so unconditional escaping is the right contract
- [x] 4.2 Replace `to_attr_url_format`'s hand-rolled escape with `value.to_s.inspect`. Its `gsub` is already **correct** for a Ruby literal (verified: `a"b` round-trips); the real defect is unescaped backslashes — `a\b` becomes a backspace and `a\"b` raises `SyntaxError`. Do **not** give it the HTML escaper. Correctness fix, not security: the method has no callers in this repo
- [x] 4.3 `spec/lib/ext/hash_spec.rb` — 9 examples, 0 failures; separator argument unchanged
- [x] 4.4 Add a `contact_form_unfiltered_html` entry to `CamaleonCms::UserRole::ROLES[:manager]` with `color: 'danger'` and inline `I18n.t(…, default: …)`, copying the `post_content_unfiltered_html` entry's shape (design D7). Label it **"Allow unfiltered HTML in contact forms"** — both toggles appear in the same role editor, so neither may carry the bare "Allow unfiltered HTML"
- [x] 4.4a Disambiguate the post-content label for the same reason: `'Allow unfiltered HTML'` → `'Allow unfiltered HTML in post content'`. Its description already said "in post content"; only the label was ambiguous
- [x] 4.5 Do **not** add a `next if value[:key].to_s == …` guard to `site_default_settings.rb`. Unlike `ROLES[:post_type]`, the only `_manager_` seed sites are the `admin` role (all keys — correct) and `client` (`{}`); `editor` and `contributor` never receive manager meta. Adding the guard would strip the key from administrators
- [x] 4.6 Confirmed: `cama_get_roles_values` returns `UserRole::ROLES` wholesale (and runs the `available_user_roles_list` hook), so the new key renders with no view change
- [x] 4.7 `spec/models/contact_form_unfiltered_html_permission_spec.rb` — 11 examples, 0 failures: the key is present in `ROLES[:manager]`; a freshly seeded `admin` role holds it while `editor`/`contributor`/`client` do not; enabling it on a custom role makes `can?(:manage, :contact_form_unfiltered_html)` true; holding it does **not** make `Post#content` bypass sanitization
- [x] 4.8 Rename `#1206`'s permission while it is still unreleased (design D8): role key `allow_unfiltered_html` → `post_content_unfiltered_html` and ability `post_unfiltered_html` → the same name, across `user_role.rb` (including both `I18n.t` key names), `ability.rb`, `post.rb`, `site_default_settings.rb`, `spec/models/post_content_sanitization_spec.rb`, and `spec/models/site_default_settings_spec.rb`
- [x] 4.9 Leave `Post#trusted_for_unfiltered_html?` named as-is — a private predicate, not a permission identifier
- [x] 4.10 Leave `openspec/changes/archive/2026-07-21-fix-content-sanitization/` untouched; an archive records what was decided at the time. The live spec is updated through this change's `MODIFIED` delta instead
- [x] 4.11 `bin/rspec spec/models/post_content_sanitization_spec.rb spec/models/site_default_settings_spec.rb` — 17 examples, 0 failures after the rename
- [x] 4.12 Re-confirmed against the `2.9.2` tag: 0 files contain either old identifier, so no data migration is needed. Re-check once more immediately before merge

## 5. Fix the plugin (separate PR, `cama_contact_form`)

- [x] 5.1 Escape the data positions in `cama_form_element_bootstrap_object`: `values[cid]`, `default_value`, `label`, `field_class`, `description`, and the `[label ci]` / `[descr ci]` substitutions
- [x] 5.2 Escape option labels in `cama_form_select_multiple_bootstrap`, in both the `value` attribute and the text position
- [x] 5.3 Escape `railscf_form_button[:name_button]` at the `[submit_label]` substitution in `forms_shorcode.html.erb`
- [x] 5.4 Leave `previous_html`, `after_html`, `template`, and `field_attributes` rendering raw — escaping them is a functional regression (design D2)
- [x] 5.5 Sanitize those four at save time in `AdminFormsController#update` with `CamaleonRecord.cama_sanitize_translatable`, unless `CamaleonCms::Ability.new(CurrentRequest.user, CurrentRequest.site).can?(:manage, :contact_form_unfiltered_html)`; fail closed (sanitize) when either context is blank, copying the shape of `Post#trusted_for_unfiltered_html?` (design D3, accepted)
- [x] 5.6 Confirm the predicate resolves as intended: admin → trusted via `can :manage, :all`; `client` and a bare custom role → untrusted; a role with a truthy `contact_form_unfiltered_html` manager key → trusted via `define_manage_rules`
- [x] 5.7 Bump `version.rb` to `0.1.10` — the builder computes that from tag 0.1.9, so both land in the same push. Not 0.2.0: Camaleon's `~> 0.1.0` would not resolve it (design D5)
- [x] 5.8 All section-3 specs pass. 73 examples, 0 failures across `spec/requests/security/`, `spec/lib/ext/hash_spec.rb` and the new permission spec

- [x] 5.9 **Found while implementing:** `Hash#to_attr_format` escaped attribute *values* but interpolated *keys* verbatim, so a `field_attributes` key of `x onfocus=alert(1) y` rendered as three attributes. Escaping cannot defend that position — the splitting characters are whitespace and `=`, not HTML metacharacters — so keys are now validated against `CAMA_HTML_ATTR_NAME` and invalid pairs are dropped. Covered in both the unit and request specs
- [x] 5.10 **Reclassified `field_attributes` as data, not markup-by-contract** (revises design D2). It is JSON, not HTML: an HTML sanitizer would corrupt it, and after 5.9 it is safe at render time. The save-time sanitization set is therefore `previous_html`, `after_html` and each field's `template` — three values, not four
- [x] 5.11 `spec/requests/security/contact_form_settings_sanitization_spec.rb` — 8 examples covering the untrusted plugins-manager, the granted role, the administrator, a caller with no plugin permission, and the fail-closed predicate. The no-context branch is unreachable over HTTP (authorization rejects first), so it is asserted directly on the predicate instead

## 6. Tests

- [x] 6.1 Cover the remaining echoing field types from the spec (`website`, `email`) in the visitor-reflection spec
- [x] 6.2 Cover the `field_attributes` JSON breakout scenario end to end, which exercises the section 4 fix through the plugin
- [x] 6.3 Add a non-regression spec asserting legitimate stored markup in `previous_html` still renders unescaped
- [x] 6.4 Add a non-regression spec asserting a visitor value of `Fish & Chips <today>` round-trips as visible text, not entities
- [x] 6.5 Mutation-verified all five fixes by reverting each in isolation; every one is caught by its intended spec, and the tree restores clean (64 examples, 0 failures). M1 value escaping -> 2 failures; M2 key validation -> 2 unit + 1 request failure; M3 `to_attr_url_format` -> 2 failures; M4 plugin `cf_h` -> 7 failures; M5 save-time sanitization -> 5 failures

## 7. Documentation

- [x] 7.1 `CHANGELOG.md` entry written with five behavior/upgrade bullets, crediting Amir Aliu and Enrik Mustafa, plus a bold notice that `cama_contact_form` is sourced from its git tag until 0.1.10 reaches RubyGems, with the exact line host applications must add. A separate `**Security bumps:**` entry records the four transitive updates
- [x] 7.2 Note in the changelog that `to_attr_format`'s output changes for all callers, including external plugins and themes
- [x] 7.3 Created `CHANGELOG.md` in the plugin repo (it had none) with a 0.1.10 entry. Dropped a bullet I had drafted claiming an `<option> selected` fix — checking the diff showed the original already compared the normalized value, so my change was a readability extraction, not a fix
- [x] 7.4 `docs/security/permissions.md` — done ahead of implementation. Documents both unfiltered-HTML permissions side by side, the two role families, granting, `CurrentRequest` fail-closed behavior, auditing, and that neither sanitizes retroactively. **Must land with the implementation, not before:** it describes `contact_form_unfiltered_html` as shipped
- [x] 7.5 Filled: the doc's "Introduced in" column and both `CHANGELOG.md` entries now link [#1215](https://github.com/owen2345/camaleon-cms/pull/1215)

## 8. Verification

- [x] 8.1 `bin/rspec` — **815 examples, 0 failures** (23m13s, includes the browser-driven feature specs)
- [x] 8.2 `bin/rubocop` on all 22 touched files — no offenses
- [x] 8.3 `bin/brakeman --no-pager` — 0 errors, 0 security warnings
- [x] 8.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — All is good!

## 9. Release and coordination

- [x] 9.1 Plugin PR [#63](https://github.com/owen2345/cama_contact_form/pull/63) merged; the builder tagged `0.1.10` in 16s and `version.rb` matches — the first aligned tag since 0.1.7. Camaleon's six Gemfiles now pin `tag: '0.1.10'` rather than a branch, so the resolved revision is immutable
- [ ] 9.2 Ask `owencio` to publish 0.1.10 to RubyGems, or to add a second gem owner — until this happens the plugin half reaches no user, since RubyGems still serves 0.1.0 from 2022-12-27
- [ ] 9.3 **After publication:** revert all six Gemfiles from the git source back to a version constraint. Left in place, CI silently tests a moving branch and a plugin-side force-push becomes a Camaleon CI failure (design, Risks)
- [ ] 9.4 Consider raising Camaleon's gemspec floor to `~> 0.1.10` so new installs cannot resolve the vulnerable 0.1.0
- [ ] 9.5 Ask the reporter for their reproduction steps, specifically which access-control issue allowed form modification and what privilege the acting account held — their chain's first step is still unverified and may not be either root fixed here

## 10. Out of scope, tracked separately

- [ ] 10.1 The two CSRF skips (`Admin::MediaController#upload`, `Admin::PostsController#ajax`) — `media#upload` permits a cross-site forced authenticated upload and deserves its own change
- [ ] 10.2 Rewriting `cama_form_element_bootstrap_object` onto `tag`/`content_tag` and `SafeBuffer` so escaping is structural rather than positional (design D4) — correct follow-up once these specs exist to protect it
- [ ] 10.3 Reviving the plugin's `test/dummy`, which cannot boot on Rails 8.1
