## Context

Two defects, one sink chain. `cama_form_element_bootstrap_object` builds a plain `String` of HTML and the shortcode view `raw`s it; `Hash#to_attr_format` builds attribute pairs with a non-HTML escape. Both are reached by user input at two different trust levels, and the admin panel shares an origin with the frontend, so any successful injection reaches an administrator's session.

The work spans two repositories with different release constraints. Camaleon is publishable by this project; `cama_contact_form` is not (RubyGems owner is `owencio` alone, latest published 0.1.0 from 2022-12-27). The design has to keep the Camaleon half shippable on its own.

## Decisions

### D1: Fix `to_attr_format` by escaping for the HTML attribute context

`gsub('"', '\"')` is replaced with `ERB::Util.html_escape` on the value. The method's job is to emit an HTML attribute list, so the value must be escaped for that context — the current behavior escapes for a Ruby string literal, which is simply the wrong target language.

`to_attr_url_format` carries the identical `gsub`, but — established by running it, not by reading it — that escaper is **correct** for its context. It emits a Ruby-ish `:key => "value"` fragment for code generation, not HTML, and `gsub('"', '\"')` is exactly right for a double-quoted Ruby literal: `'a"b'` round-trips through `eval`. The two methods do not share an escaper, and this one must not be given the HTML escaper, which would corrupt the generated code with entities.

It is nonetheless broken, in a different and non-security way: it escapes the quote but not the backslash, which is itself an escape character inside a double-quoted literal.

| input | emitted | result |
|---|---|---|
| `a"b` | `:key => "a\"b"` | round-trips correctly |
| `a\b` | `:key => "a\b"` | backslash becomes a backspace escape |
| `a\"b` | `:key => "a\\"b"` | **SyntaxError** — literal does not close |

The fix is to stop hand-rolling the escape and emit `value.to_s.inspect`, which produces a complete, correctly escaped double-quoted literal. This is a correctness fix, not a security one: the method has **no callers anywhere in this repo**, so nothing currently depends on either the bug or the fix. It is in scope only because leaving a method that raises `SyntaxError` on ordinary input, immediately beside one being fixed for a security defect, invites the next reader to assume both were reviewed.

**Alternative rejected — leave `to_attr_format` and fix only the plugin.** The method advertises escaping (`gsub('"', …)` is unmistakably an escape attempt) and is public API in a shipped gem. Leaving a broken escaper in place because the one caller we can see has been patched invites the next caller to trust it. The `AGENTS.md` note that plugin and theme consumers cannot be enumerated from this repo argues for fixing the primitive.

**Alternative rejected — delete both methods.** They are public `Hash` extensions with unknown external callers. Removal is a breaking change with no security benefit over fixing them.

### D2: Split contact-form values into *data* and *markup by contract*

The plugin's fields are not uniform, and escaping everything would break documented functionality.

| position | source | classification |
|---|---|---|
| `values[cid]` (flash) | unauthenticated visitor | **data** — always escape |
| `default_value` | form definition | **data** |
| `label`, option `label` | form definition | **data** |
| `field_class` | form definition | **data** |
| `field_options[:description]` | form definition | **data** |
| `railscf_form_button[:name_button]` | form settings | **data** |
| `field_options[:template]` | form definition | **markup by contract** |
| `field_attributes` | form definition | **markup by contract** (via `to_attr_format`) |
| `railscf_mail[:previous_html]` / `[:after_html]` | form settings | **markup by contract** |

The four markup positions are HTML by design — `previous_html`/`after_html` exist to wrap the form in site markup, and `template` is the per-field wrapper whose placeholder syntax (`[ci]`, `[label ci]`, `[descr ci]`) only makes sense as markup. Escaping them would be a functional regression, not a fix. Everything else is a value a user types into a plain-text input, and escaping it costs nothing legitimate.

### D3: Govern markup-by-contract fields with save-time sanitization (accepted)

Leaving the four markup fields fully raw preserves the plugins-manager → administrator escalation, which is the most severe half of the report. Escaping them breaks the feature. The middle path is the one Camaleon already chose for post content in [#1206](https://github.com/owen2345/camaleon-cms/pull/1206): sanitize at save time with a role-based bypass.

`AdminFormsController#update` sanitizes these four values with `CamaleonRecord.cama_sanitize_translatable` — the same entry point `Post#sanitize_content` uses — unless the saving user is trusted, and fails closed when context is missing. Rendering stays raw, so previously stored legitimate markup keeps working.

**The trust predicate is `Ability#can?(:manage, :contact_form_unfiltered_html)`, not `post_content_unfiltered_html`.** The existing key does not fit: `Ability` defines `:post_content_unfiltered_html` against a `CamaleonCms::PostType`, resolved from `@roles_post_type[:post_content_unfiltered_html]`, and `Post#trusted_for_unfiltered_html?` passes a concrete `post_type` to it. Contact forms are `TermTaxonomy` records with no post type, so there is nothing to pass. Reusing the key would mean inventing a fake post-type argument or reading role meta directly, both of which fork the trust model rather than share it.

`can?(:manage, :contact_form_unfiltered_html)` avoids that and needs no new Camaleon code:

- Admins already satisfy it, because `Ability#initialize` grants `can :manage, :all` for `user.admin?`.
- `client` and every other non-admin role fails it, because `define_manage_rules` only grants `:manage` on keys present and truthy in the role's `_manager_<site_id>` meta.
- It is extensible without further work: `define_manage_rules` ends with a generic loop granting `:manage` on *any* truthy manager key, so a site that later wants to delegate this to a non-admin role can add a `contact_form_unfiltered_html` manager key and it is honored automatically.

So the shipped default is **administrators only**, with an opt-in path that costs nothing now. `Post#trusted_for_unfiltered_html?` supplies the surrounding shape to copy: read `CurrentRequest.user` and `CurrentRequest.site`, return false (sanitize) if either is blank — guarding the site as well, since `Ability#initialize` dereferences it for non-admin users and would otherwise raise mid-save.

The boundary is stated in the spec: `post-content-sanitization` governs `Post#content` per post type; this capability governs contact-form settings site-wide.

**Alternative considered — sanitize at render instead of save.** Rejected: it re-sanitizes on every page view for no benefit, and it cannot distinguish who authored the value, which is the whole point of the trust split.

### D4: Escape at each interpolation point, not by rewriting the helper

`cama_form_element_bootstrap_object` is applied `ERB::Util.html_escape` at each data position, leaving its string-building structure intact.

**Alternative rejected for now — rewrite using `tag`/`content_tag` and `SafeBuffer`.** That is the idiomatic Rails form and would make escaping structural rather than positional, so future edits cannot reintroduce the bug. It is also a full rewrite of a 60-line method with no test coverage anywhere, inside a security patch, in a repo whose suite cannot boot. `AGENTS.md` calls for surgical changes; the rewrite is the right follow-up once the regression specs exist to protect it, not the right vehicle for the fix.

### D5: Release the plugin as 0.1.10, not 0.2.0

Strict semver argues for a minor bump: escaping previously-rendered markup is a breaking behavior change. It is nonetheless released in the 0.1.x line, because Camaleon's gemspec pins `~> 0.1.0` (`>= 0.1.0, < 0.2.0`). A 0.2.0 would not resolve for any existing Camaleon install — including through the git override this change adds — and a security fix nobody can install protects nobody. The behavior changes are documented prominently in the changelog instead, matching how `post-content-sanitization` handled the same tension.

This also determines the git-override mechanics: the branch's `version.rb` must satisfy `~> 0.1.0` for Bundler to resolve it at all.

### D6: Git source in all six Gemfiles, reverted after publication

The main `Gemfile` and all five `gemfiles/*.gemfile` gain:

```ruby
gem 'cama_contact_form', git: 'https://github.com/owen2345/cama_contact_form', branch: '<fix branch>'
```

All five matrix gemfiles are covered because both workflows consume them: `current_support.yml` runs `rails_7_1` through `rails_8_1`, `experimental_support.yml` runs `rails_edge` and `rails_8_1`. Omitting any one would leave a matrix leg resolving 0.1.0 from RubyGems and failing the new specs, which would read as a flaky suite rather than a missing override.

The pattern is already documented for host apps in `docs/example_gemfile.rb`, comment included: *"already dependency of main framework, only here to use latest git source"*. Bundler accepts re-declaring a `gemspec`-declared dependency with a source as long as the version constraint still holds — see D5.

This override is temporary and must be reverted to a version constraint once 0.1.10 publishes. Until then Camaleon's CI tests against a moving git ref, which is the accepted cost of writing the regression specs before the fix can be released. Pinning `branch:` rather than a bare `git:` keeps the ref explicit; pinning `ref:` to a SHA would be tighter still but requires an extra round trip after every plugin commit.

### D7: Surface the permission as a first-class manager role key

A permission that exists only as hand-edited role meta is a support burden: the capability is real, but nothing in the admin UI reveals it, so the first site that wants to delegate raw-HTML editing has to be told to write meta by hand. `contact_form_unfiltered_html` is therefore added to `CamaleonCms::UserRole::ROLES[:manager]` in the same change.

`app/helpers/camaleon_cms/user_roles_helper.rb:5` reads `CamaleonCms::UserRole::ROLES` to build the role editor, so adding the entry surfaces the checkbox with no view changes. The entry copies the `post_content_unfiltered_html` pattern verbatim — inline `I18n.t(…, default: …)` for label and description, and `color: 'danger'` to mark it as a privilege-granting toggle. No `config/locales` entries are required; the existing post-type key carries its strings inline the same way.

**Named for what it grants, not for the mechanism.** An earlier draft called this key `unfiltered_html`. That was rejected in review as indistinguishable from the post-type key `post_content_unfiltered_html`: two near-identical names, in two different sections of `ROLES`, with two different scopes and two different check forms is a standing invitation to grant the wrong one. `contact_form_unfiltered_html` states its subject in the name, so `can?(:manage, :contact_form_unfiltered_html)` reads unambiguously against `can?(:post_content_unfiltered_html, post_type)`.

It is longer than its neighbours (`media`, `plugins`, `settings`, `custom_fields`), but `select_eval` sets the precedent that a manager key may name one specific feature rather than an admin section. Clarity wins over brevity for a permission whose misuse grants script execution in an administrator's session.

`post_content_unfiltered_html` was also considered for the manager key and rejected outright: `define_manage_rules` turns the key straight into the ability, so it would yield `can?(:manage, :post_content_unfiltered_html)` and put two identically named keys in two sections of `ROLES`.

**No seeding exclusion is needed**, unlike the post-type key. `site_default_settings.rb` writes `_manager_<site_id>` in exactly two places: the `admin` role receives every manager key set to `1` (correct — admins are trusted, and already hold `can :manage, :all` regardless), and the `client` role receives `{}`. The `editor` and `contributor` roles never have `_manager_` seeded at all. So the new key defaults to admin-only without the `next if value[:key].to_s == …` guard that [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) had to add for `ROLES[:post_type]`. This asymmetry is worth stating because the obvious assumption — "copy the exclusion too" — would be wrong and would strip the key from the admin role.

**Scope note.** The name deliberately binds the grant to one feature. An earlier draft made it a general "may store raw HTML outside post content" permission on the theory that future consumers should reuse it rather than mint a third trust flag. That is the wrong trade for a security-relevant grant: a permission whose meaning silently widens as features are added violates least privilege, because an administrator who enables it for contact forms cannot know what else it will authorize in a later release. A second consumer should introduce its own key, named for its own subject. Permission proliferation is a documentation problem; silent scope creep in an existing grant is a security one.

### D8: Rename the post-content permission to match, while it is still unreleased

Naming only the new key well would have left the pair half-fixed. `#1206`'s key was `allow_unfiltered_html` and its ability `post_unfiltered_html` — a prefix that describes nothing, and a key that does not match its own ability. Both are renamed to `post_content_unfiltered_html`, so each post-content identifier states its subject and the key equals the ability, matching how manager-family keys resolve through `define_manage_rules`.

**This is free, and only right now.** Neither identifier appears in the `2.9.2` tag: `#1206` merged 2026-07-21, after the 2026-05-01 release, and sits unreleased alongside this change in `Unreleased`, targeted at 2.9.3. No published version exposes either name, so no site has role meta keyed on them and no migration or backfill is required. The moment 2.9.3 ships, the same rename would need a data migration for `_post_type_<site_id>` meta and a deprecation path — worth doing now precisely because the window is closing.

Renamed across `user_role.rb` (including its two `I18n.t` key names, which have inline defaults and no `config/locales` entries), `ability.rb`, `post.rb`, `site_default_settings.rb`, and the two model specs. `Post#trusted_for_unfiltered_html?` keeps its name — it is a private predicate, not a permission identifier, and renaming it would churn `#1206`'s code for no clarity gain.

**The archived change is left untouched.** `openspec/changes/archive/2026-07-21-fix-content-sanitization/` still says `allow_unfiltered_html` throughout. An archive records what was decided at the time; rewriting it to match a later rename would falsify that record. The live `openspec/specs/post-content-sanitization/spec.md` is updated through this change's `MODIFIED` delta instead, which is where a rename belongs.

## Risks

- **The git override outlives its purpose.** If 0.1.10 publishes and nobody reverts, Camaleon's CI silently keeps testing a branch instead of the released gem, and a `main`-branch force-push in the plugin repo becomes a Camaleon CI failure. Mitigated by a task and a changelog note; not mitigated structurally.
- **The rename window is genuinely closed after 2.9.3.** If any part of this change slips to a later release while `#1206` ships in 2.9.3, the rename stops being free and must be dropped or given a migration. The two must ship together.
- **`to_attr_format` has unknown external callers.** Escaping changes their output. Any caller currently passing pre-built markup through an attribute value breaks. That is the intended effect, but it will surface as a bug report from a plugin author rather than as a security acknowledgement.
- **D3 expands the plugin PR** beyond escaping into permission checking, and the plugin has no test harness to catch mistakes there. The Camaleon-side specs cover rendering, not the plugin's save path, so the save-time sanitization is the least-covered part of this change.
- **The reporter's access-control step is unverified.** They did not share reproduction steps, and form editing requires `:manage, :plugins` on `master`. If they used a hole that still exists and is not this one, closing these two roots does not close their chain. Requesting the steps is tracked as a task.
