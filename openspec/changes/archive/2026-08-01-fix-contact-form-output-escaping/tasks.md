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


## 9. HANDOFF — read this first

The design turned over three times in review. **Sections 1–8 above describe superseded designs and are kept only as a record of how the work got here.** Anything in them about *escaping* or *sanitizing* contact-form values is obsolete. What was actually built is below.

### The model that was built

Nothing is ever rewritten. Content is stored and rendered exactly as written, or refused.

| writer | outcome |
|---|---|
| author with `:manage, :contact_form_unfiltered_html` | anything stored verbatim — markup, script, event handlers — and delivered to guests as written |
| author without it | save refused, naming only the offending *key*; nothing stored, record untouched |
| visitor | submission refused; nothing stored, no mail sent, nothing echoed back |
| structural values (`cid`, field type, `maxlength`) | allowlisted for **everyone**, including admins — a malformed field type is a corrupt record, not a capability |

The plugin performs **no escaping at all**. `grep -rE "escapeHTML|html_escape|to_attr_format|cf_h" app/` returns nothing but comments. Enforcement is entirely at the gate:

- `AdminFormsController#update` — validates *before* touching the record, fails on the first offender.
- `ContactFormControllerConcern#validate_to_save_form` — refuses and returns immediately, before reCAPTCHA or any other validation.
- `FrontController#save_form` — a submission containing anything malign is refused whole; nothing is stashed into `flash[:values]`.

Rejection criteria are deliberately narrow, one per HTML context:

- element content → an HTML sanitizer would change it
- attribute value → contains `"`
- textarea redisplay → contains `</textarea` (a quote is ordinary prose here and must be accepted)

### Camaleon-side changes (unaffected by the revisions, still correct)

`Hash#to_attr_format` escapes values with `CGI.escapeHTML` and drops keys that are not valid attribute names. **It keeps escaping** — it is public API that external plugins and themes hand untrusted data to. The contact form stopped calling it and emits its own attributes verbatim (`cf_attrs`), because there the values are gated at save. Do not "unify" these two.

`to_attr_url_format` emits `value.to_s.inspect`. The permission rename (D8) and the new manager key (D7) are unaffected.

### Two traps that bit during this work — do not reintroduce

1. **The rejection message must never quote back what it rejected.** Both the admin and frontend flash partials render with `raw(flash[...])`. An earlier revision interpolated the author's own field label into the error, which made refusing an injection a way to perform one. Messages now name only the controller's own constants (`previous_html`, `template`, `option label`).
2. **`type` in `cama_form_select_multiple_bootstrap` is the control type, not the field type.** A `checkboxes` field renders `type="checkbox"`, a `dropdown` renders a `<select>`. A bulk edit conflated them and no spec caught it until one was written.

### Verification state

`spec/requests/security/` — 83 examples, 0 failures. Every fix was mutation-verified by reverting it in isolation and confirming the intended spec fails. Two specs were found worthless that way and rewritten: one that could not reach the branch it claimed to guard, and one whose early return could be deleted with nothing failing, because every fixture failed validation for another reason.

Not re-run since the final revision: full `bin/rspec`, rubocop, brakeman, zeitwerk.

## 9a. Five gate-coverage holes found after the handoff — now closed

The handoff's position list was incomplete, and under this design an omitted position is not degraded but **unprotected**. All five were reproduced as live XSS before being fixed: each was reachable by a role holding `:manage, :plugins` alone, which is the exact boundary this change exists to close. Found by re-deriving the position table against the renderer rather than by reading the list.

- [x] 9a.1 **`default_value` on a `paragraph`/`textarea` field.** Rendered as `<textarea>` RCDATA content but judged by the attribute rule, so `</textarea><script>alert(1)</script>` — which contains no double quote — passed. Its context now follows the field type, matching the split the front controller already applied to a visitor's value.
- [x] 9a.2 **`description`.** Judged only as markup. But `[descr ci]` is substituted wherever the *authored* template puts it, and `<div title="[descr ci]">` passes the sanitizer untouched, so `x" onmouseover="alert(1)` landed as a live handler. It now carries the attribute rule as well, as `label` already did.
- [x] 9a.3 **`field_attributes` keys.** Validated for shape only, and `onfocus` is a perfectly well-formed attribute name carrying a quote-free value. Event-handler names are now refused by an `on` prefix test — the rule HTML sanitizers use; a list of known handler names fails open as the platform adds more.
- [x] 9a.4 **`railscf_message`.** Not checked at all. Every value flows through `the_message` into `flash[:contact_form]`, which the frontend flash partial renders with `raw` — on the failure path *and* the success path. All values in the hash are now markup-checked, without enumerating keys, so a message added later is covered.
- [x] 9a.5 **`recaptcha_site_key`.** The recaptcha gem interpolates it into `data-sitekey="…"` with no escaping. Now attribute-checked. The rejection is spec'd at the gate rather than at the render: the gem skips emitting the tag entirely in the test environment, so there is no rendered attribute to assert against.
- [x] 9a.6 Mutation-verified all five by reverting each in isolation; every one is caught by its intended spec, and the tree restores clean. `spec/requests/security/` — **103 examples, 0 failures**.
- [x] 9a.7 Removed the stale escaping-era comment block left above the rejection-model one in `admin_forms_controller.rb`, the duplicated doc line on `first_unpermitted_html_key`, the "sanitized on save" note in `forms_shorcode.html.erb`, and an empty `describe` block holding only comments in `contact_form_output_escaping_spec.rb`.

**Consequence for the design:** D2's position table is the security boundary, and it is maintained by hand. This is now recorded as the change's largest structural risk and the strongest argument for the D4 rewrite onto `tag`/`content_tag`.

## 9b. Fifteen findings from the post-handoff review — now fixed

The rejection design was reviewed end to end against the renderer and the two mail templates. The
position table in D2 was the weak point again, and for the same structural reason as 9a: it was
maintained by hand against a renderer whose contexts the *author* could move.

**Gate bypasses (each reproduced as live XSS by a role holding only `:manage, :plugins`)**

- [x] 9b.1 **The template decided the context, so the table was not true.** `<div class='[descr ci]'>`
  put a description inside a single-quoted attribute, where an apostrophe escapes and no rule was
  looking for one; `<div title="[ci]">` put a whole `<textarea>` inside an attribute. Fixed
  structurally rather than by adding rules: a template placing a placeholder **inside a tag** is
  refused for everyone. `description` consequently drops the attribute rule, which also makes a
  quote in a description ordinary prose again.
- [x] 9b.2 **The sanitizer comparison is blind to what the parser drops first.** An unterminated
  attribute (`<div class="a" onmouseover="alert(1)" x="`) serializes to `""` on both sides; a
  `<td onmouseover=…>` is foster-parented away before the sanitizer sees it and materializes as soon
  as the page opens table context. Both refused now, structurally.
- [x] 9b.3 **`[label ci]`/`[descr ci]` were substituted after `[ci]`**, over the field markup the
  first pass had just produced — so a visitor typing the literal `[label ci]` had the author's label
  spliced into the textarea echoing their own words back. One pass now.
- [x] 9b.4 **A Hash-shaped submitted value skipped the visitor gate** and then supplied the closing
  quote through `Hash#to_s`. The submitted value is judged as the renderer interpolates it.
- [x] 9b.5 **The notification e-mail is a markup sink and was ungated for visitor values.**
  `cama_replace_codes` splices them into the author's body and the mailer renders it with `raw`.
  Active markup is refused; prose is not. `subject`/`subject_answer` were in no list at all.
- [x] 9b.6 **`dangerous_url?` decoded with `CGI.unescapeHTML`**, which knows the five legacy entities
  and nothing else, so `formaction="javascript&colon;alert(1)"` passed while a browser resolves it.
  The HTML parser now does the decoding.
- [x] 9b.7 **`rel` and `target` had been added to the safe list.** Rails omits them deliberately:
  `rel="opener"` re-enables the `window.opener` handle. Removed.

**Broken for everyone**

- [x] 9b.8 **Every checkbox, radio and file submission was refused.** `Array#to_s` is `inspect`, so
  the array's own string form always carries a quote. The spec named after this case asserted only
  `have_http_status(:redirect)`, which is true on both branches — it now asserts what was stored.
- [x] 9b.9 **A refused save discarded the author's work.** The editor is repopulated from the
  submitted params (the 9a "KNOWN GAP", closed).

**Crashes reachable from an ordinary request**

- [x] 9b.10 `POST save_form` with an unknown id → `nil.fields`, an unauthenticated 500.
- [x] 9b.11 `fields=` → `String#each`; a scalar settings container → `TypeError` on every public
  page; a nested non-scalar in `railscf_mail` → `NoMethodError` *after* the response row was stored
  and the owner e-mailed; `required` → `String#to_bool` raises; an empty option list → `nil.each`;
  `field_attributes` of `[1,2]` → `TypeError`. All refused at the gate, and the model gained
  `mail_settings`/`form_button_settings`/`message_settings` so a form with no settings still renders.

**False refusals and misdirection**

- [x] 9b.12 A translated value containing `<` (`<!--:en-->Age < 18<!--:-->`) was refused, because
  every `<` counted as a tag open. Prose containing `-->` was refused by a comment-count comparison
  that only ever produced false positives. `data-*`, `aria-*`, `role` and `tabindex` were refused,
  which is most of what `template` exists for.
- [x] 9b.13 The refusal named a generic rule: `btn "primary"` in Custom Class was reported as
  "contains HTML". The message now follows the rule that fired.

**Cost**

- [x] 9b.14 The number and size of parses were caller-chosen. 4093 option labels measured **17 s** of
  CPU in one request; a 1 MB template measured **20 s**. Field count, option count and value size are
  capped, and each check parses once rather than twice.

**Process**

- [x] 9b.15 Both replacement spec files were untracked while the spec they replace was staged for
  deletion — committing the tree would have removed the only tracked coverage of the admin gate.
  Tracked now, and `.bundle/` is gitignored so the local override cannot be committed.

- [x] 9b.16 Full gate re-run after the fixes: `bin/rspec` — **952 examples, 0 failures**;
  `spec/requests/security/` — **189 examples, 0 failures**; `bin/rubocop` clean on the three changed
  spec files; `bin/brakeman --no-pager` — 0 warnings, 0 errors;
  `(cd spec/dummy && bin/rails zeitwerk:check)` — all good; `openspec validate --strict` passes.

## 10. Remaining work

- [x] 10.1 Rewritten for the rejection model: `design.md` (Context, D1 addendum, D2, D3, D4, D5, D6, Risks), `proposal.md`, `specs/contact-form-output-escaping/spec.md` (full rewrite — 9 requirements), `specs/post-content-sanitization/spec.md` (remedy difference + the stale "SHALL be sanitized" scenario), `CHANGELOG.md`, `docs/security/permissions.md`, and the plugin's `CHANGELOG.md` (new 0.1.12 entry). `openspec validate --strict` passes
- [x] 10.2 Plugin committed on `security/reject-unsafe-content`, [PR #65](https://github.com/owen2345/cama_contact_form/pull/65) opened, merged and released — `cama_contact_form` 0.1.12 is on RubyGems
- [x] 10.3 Better than repointing at a tag: the override is removed from all six Gemfiles outright, and `camaleon_cms.gemspec` raises the dependency to `~> 0.1.12`. Left at `~> 0.1.0` the range would still have admitted the vulnerable 0.1.0
- [x] 10.4 Local Bundler override removed (`bundle config unset local.cama_contact_form && rm -rf .bundle`); `Gemfile.lock` re-resolved and now carries no git source. `.bundle/` stays gitignored
- [ ] 10.5 Amend/extend the Camaleon commit — the pushed branch predates the rejection design — and update the [#1215](https://github.com/owen2345/camaleon-cms/pull/1215) body
- [ ] 10.6 `openspec archive fix-contact-form-output-escaping -y` on the branch, before merge
- [x] 10.7 Full gate: `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` — all green, see 9b.16
- [ ] 10.8 Re-confirm against the `2.9.2` tag that neither `allow_unfiltered_html` nor `post_unfiltered_html` appears, so the D8 rename still needs no migration

## 11. Superseded releases

`0.1.10` (uniform escaping) and `0.1.11` (context-aware escaping) are tagged and released on GitHub but describe designs reversed in review. `0.1.12` supersedes both. Neither reached RubyGems, so nobody can have installed them.

## 12. Follow-ups — deliberately not part of this change

**Was blocked on publication — now resolved**

- `cama_contact_form` 0.1.12 is published to RubyGems. Host applications need nothing in their own `Gemfile`; `bundle update camaleon_cms` is enough.
- The six Gemfiles no longer carry the git source, and the gemspec requires `~> 0.1.12` — raised rather than merely reverted, because `~> 0.1.0` still admitted the vulnerable 0.1.0 and an application whose lock already named it would have stayed there. `Gemfile.lock` carries no git source and the local Bundler override is gone.
- `docs/example_gemfile.rb` still git-sources the plugin. Left alone: it predates this work by two years, is one line of a block that git-sources several Camaleon plugins on purpose for people tracking master, and now resolves a master that contains the fix.

**Open question to the reporters**

- Amir Aliu and Enrik Mustafa described a broken access control step that let them modify an existing form. Form editing requires `:manage, :plugins` on `master`, and no reproduction steps were shared. If they used a hole that still exists, their chain is not fully closed.

**Separate changes**

- The two CSRF skips (`Admin::MediaController#upload`, `Admin::PostsController#ajax`). `media#upload` permits a cross-site forced authenticated upload — a real finding, deliberately excluded here.
- `cama_form_element_bootstrap_object` still builds HTML by string concatenation. It is now safe by construction rather than by escaping, but a rewrite onto `tag`/`content_tag` would make it structurally so. Specs now exist to protect such a rewrite.
- The plugin's `test/dummy` cannot boot on Rails 8.1, which is why all regression coverage lives in Camaleon.
- Pre-existing in `validate_to_save_form`: `fields[cid].match(/@/)` raises `NoMethodError` on `nil` for an email field omitted from the request. The early bail avoids it for malign input only.
