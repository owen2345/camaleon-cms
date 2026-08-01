## Why

A reporter disclosed a chain against Camaleon 2.9.0/2.9.1 that they described as "missing or improperly enforced CSRF protections on certain admin controller endpoints," combined with a broken access control issue, yielding unauthorized administrator account creation.

Triage found the CSRF attribution wrong and the underlying injection real — in two places, one of them in Camaleon itself.

**The CSRF half does not reproduce.** `CamaleonCms::CamaleonController` applies `protect_from_forgery with: :exception` globally, and `master` carries exactly two skips — `Admin::MediaController#upload` and `Admin::PostsController#ajax`. Neither creates users; `Admin::UsersController#create` is fully protected. More fundamentally, the described payload never needed a CSRF weakness: it executes as same-origin JavaScript, so it reads the token straight from `csrf_meta_tags` in the admin layout. CSRF protection is powerless by construction against script running on the origin it protects. (The two skips deserve their own triage — `media#upload` permits a cross-site forced authenticated upload — but they are not part of this chain and are out of scope here.)

**The injection half is real.** It has two independent roots.

### Root 1 — unescaped interpolation in `cama_contact_form`

The plugin is not merely compatible with Camaleon; it is a hard gemspec dependency (`s.add_dependency 'cama_contact_form', '~> 0.1.0'`) installed with every site. `Plugins::CamaContactForm::MainHelper#cama_form_element_bootstrap_object` assembles form markup by raw string interpolation with no escaping at any position, and `forms_shorcode.html.erb` emits the result through `raw`. Two trust levels reach those sinks:

- **Unauthenticated visitors.** `FrontController#save_form` stores raw `params[:fields]` into `flash[:values]` on any validation failure. The shortcode reads it back as `values_fields` and interpolates it into `value="#{values[cid]}"` and `<textarea>…</textarea>`. A submission that deliberately fails validation and carries `" autofocus onfocus="…` breaks out of the attribute. Flash is session-scoped, so this fires in the submitter's own browser — self-XSS in isolation, but it is the same missing-escape defect and needs no credentials at all.
- **Holders of `:manage, :plugins`.** `PluginsAdminController#authorize_plugin` gates form editing on that permission, which `Ability#define_manage_rules` grants per role via `_manager_<site_id>` meta — so a non-admin role can hold it. Every form-definition field (`label`, `default_value`, option labels, `field_class`) is interpolated unescaped and rendered on any page carrying the `[forms slug=…]` shortcode. Because the admin panel is same-origin with the frontend and Camaleon sets no CSP outside `/media/`, script injected there runs with an administrator's session when they view that page, and can drive `POST /admin/users` with a freshly read CSRF token.

That second path is a genuine privilege boundary crossing: **plugins-manager → administrator**. It holds whether or not the reporter's unstated access-control step still works, so this change does not depend on reproducing their exact chain.

### Root 2 — `Hash#to_attr_format` does not escape for HTML

`lib/ext/hash.rb:6` builds attributes as:

```ruby
res << "#{key} = \"#{value.to_s.gsub('"', '\"')}\""
```

`gsub('"', '\"')` is a Ruby/C string escape applied to an HTML context, where a backslash escapes nothing. A value of `x" onfocus=alert(1) y="` yields `class = "x\" onfocus=alert(1) y=\""`, and the browser reads `class="x\"` followed by a live `onfocus` attribute. The method looks like it sanitizes and does not.

This is **Camaleon's own code**, not the plugin's. It is currently unused inside Camaleon, but it is a public extension on `Hash` shipped in the gem, and the contact form routes user-controlled `field_attributes` straight through it. Per `AGENTS.md`, most plugins and themes live in separate gems, so the set of callers cannot be enumerated from this repo — the fix must assume external consumers exist.

Root 2 matters disproportionately for delivery: Camaleon is a gem this project can publish, whereas `cama_contact_form` is owned solely by `owencio` on RubyGems and still serves 0.1.0 from December 2022. Fixing `to_attr_format` ships to users on Camaleon's own release cadence, independent of the plugin's publication blocker.

### Why the spec and tests live here

The plugin's escaping defect is a property of Camaleon's extensions, not of plugin-local code: the sinks consume `String#translate` (`lib/ext/translator.rb`), `Hash#to_attr_format` (`lib/ext/hash.rb`), `String#cama_true?`, `cama_captcha_tag`, and `hooks_run`. `translate` returns a plain `String`, so nothing in the chain is `html_safe`-aware. Testing the helper in the plugin repo would mean stubbing the very extensions whose behavior causes the bug. The plugin also has no working harness — its `test/dummy` is a Rails 4-era skeleton that cannot boot on Rails 8.1 — and making Camaleon a dev dependency of the plugin would be circular.

## What Changes

- Add an `html-attribute-escaping` capability and fix `Hash#to_attr_format` / `Hash#to_attr_url_format` to escape for their actual output context.
- Add a `contact_form_unfiltered_html` key to `CamaleonCms::UserRole::ROLES[:manager]`, so the trust boundary the plugin fix depends on is visible and assignable in the role editor rather than existing only as hand-written role meta.
- Add a `contact-form-output-escaping` capability specifying that the plugin **rewrites nothing**: contact-form content is stored and rendered verbatim, or the save is refused. It enumerates every value that reaches the page, the HTML context each renders in, and the narrow criterion that refuses it.
- Add regression specs covering both trust levels: an unauthenticated visitor's reflected payload, and a plugins-manager's stored payload rendered on a frontend page.
- Point `cama_contact_form` at its git source in the main `Gemfile` and in all five `gemfiles/*.gemfile` used by the CI matrix, so the specs run against the fixed code before it is published. Reverted to a version constraint once the fixed gem reaches RubyGems.
- The plugin-side gate is implemented in `owen2345/cama_contact_form` as a separate PR (`admin_forms_controller.rb`, `contact_form_controller_concern.rb`, `front_controller.rb`, `main_helper.rb`), released as 0.1.12.

**The capability keeps the name it was opened under.** It no longer describes escaping — that design was tried twice and reversed — but renaming it now would churn the change ID, the branch, the PR and both changelogs for no gain. Its first requirement says so outright.

**This change deliberately does not touch the two CSRF skips.** They are a separate finding with a separate risk profile and belong in their own change.

## Capabilities

### New Capabilities

- `html-attribute-escaping`: the escaping contract for `Hash#to_attr_format` and `Hash#to_attr_url_format`, which are public API shipped in the gem and used by external plugins and themes.
- `contact-form-output-escaping`: how `cama_contact_form` renders form definitions and visitor-submitted values into HTML — every value verbatim — and the gate that makes that safe: which positions are checked, in which HTML context, and what each refuses.

- `post-content-sanitization`: its permission is renamed from `allow_unfiltered_html` to `post_content_unfiltered_html`, and the ability from `post_unfiltered_html` to the same name, so both post-content identifiers state their subject and match each other. Behavior is otherwise unchanged. A new scenario pins that holding the post-content grant does not widen contact-form trust.

This change reuses `post-content-sanitization`'s *trust shape* — a role-based bypass, read from `CurrentRequest`, failing closed when context is missing — but neither its permission nor its remedy. The key does not fit: it resolves against a `CamaleonCms::PostType`, and contact forms have none, so trust here is `can?(:manage, :contact_form_unfiltered_html)`, which needs no new Ability code and defaults to administrators only (design D3, D7). The remedy differs deliberately: post content is sanitized on save, while a contact-form save is refused. Post content is long-form prose where quietly dropping a tag is a reasonable trade; a form definition is configuration, where the author needs to know their change did not take effect.

## Impact

- **Specs (new):** `openspec/specs/html-attribute-escaping/spec.md` and `openspec/specs/contact-form-output-escaping/spec.md` via this change's deltas.
- **Camaleon code:** `lib/ext/hash.rb`, `app/models/camaleon_cms/user_role.rb`, plus new specs under `spec/`. No view changes — `user_roles_helper.rb:5` builds the role editor from `ROLES`, so the new key surfaces on its own. No `config/locales` entries — the new key carries its label and description as inline `I18n.t` defaults, matching the existing `post_content_unfiltered_html` entry.
- **Camaleon docs:** `docs/security/permissions.md` gains an "Unfiltered HTML" section documenting both permissions side by side. The file previously described only the manager family, so its intro now distinguishes manager from post-type permissions. This also closes a documentation gap left by [#1206](https://github.com/owen2345/camaleon-cms/pull/1206), which shipped `post_content_unfiltered_html` without describing it here.
- **Camaleon config:** `Gemfile` and `gemfiles/rails_7_1.gemfile`, `rails_7_2`, `rails_8_0`, `rails_8_1`, `rails_edge` — all five are exercised by the CI matrix (`current_support.yml` runs 7.1–8.1; `experimental_support.yml` runs `rails_edge` and `rails_8_1`).
- **Plugin repo (separate PR):** `app/controllers/plugins/cama_contact_form/admin_forms_controller.rb`, `app/controllers/concerns/plugins/cama_contact_form/contact_form_controller_concern.rb`, `app/controllers/plugins/cama_contact_form/front_controller.rb`, `app/helpers/plugins/cama_contact_form/main_helper.rb`, `app/views/plugins/cama_contact_form/forms_shorcode.html.erb`, `lib/cama_contact_form/version.rb`, `CHANGELOG.md`.
- **Behavior change (Camaleon):** `to_attr_format` now emits `&quot;` where it previously emitted `\"`. Any caller that relied on the broken output to inject markup through an attribute value stops working — that is the fix. Callers passing ordinary values see correctly quoted attributes for the first time.
- **Behavior change (Camaleon):** the role editor gains an "Allow unfiltered HTML in contact forms" toggle in its manager section. It is off for every role except `admin`, which receives it through the existing all-manager-keys seeding in `site_default_settings.rb`. Existing sites are unaffected until an administrator enables it.
- **Behavior change (plugin):** a save that previously succeeded may now be refused. An author without `can?(:manage, :contact_form_unfiltered_html)` who puts HTML in a field label, description, template, CSS class, default value, custom attributes, response message, option label, reCAPTCHA site key or form wrapper is told which setting to fix — named as `template`, `option label` and so on, never as the field itself and never by quoting back the refused content — rather than having it quietly rewritten. Nothing is escaped or sanitized at any point.
- **Behavior change (plugin):** a visitor's submission is refused rather than escaped, and refused whole — if any field carries a payload, none of the submission is echoed back. Ordinary punctuation is unaffected: a quote is accepted in a message, and `Fish & Chips <today>` round-trips as written.
- **Behavior change (plugin):** `cid`, `field_type` and `maxlength` are allowlisted for every author, administrators included. The permission does not lift this — a malformed field type is a corrupt record, not a capability.
- **No retroactive effect:** the gate runs on save, so content stored before this release keeps rendering until the form is saved again. Nothing is rewritten after the fact.
- **Publication risk:** RubyGems serves `cama_contact_form` 0.1.0 and only `owencio` can push. Until that resolves, the plugin half protects only installs overriding the source in their own `Gemfile`; the `to_attr_format` half ships normally with Camaleon.
