## Context

Two defects, one sink chain. `cama_form_element_bootstrap_object` builds a plain `String` of HTML and the shortcode view `raw`s it; `Hash#to_attr_format` builds attribute pairs with a non-HTML escape. Both are reached by user input at two different trust levels, and the admin panel shares an origin with the frontend, so any successful injection reaches an administrator's session.

The work spans two repositories with different release constraints. Camaleon is publishable by this project; `cama_contact_form` is not (RubyGems owner is `owencio` alone, latest published 0.1.0 from 2022-12-27). The design has to keep the Camaleon half shippable on its own.

**The plugin half of this design turned over three times.** Uniform escaping (0.1.10) closed the hole and broke the documented ability to put markup in a field label. Context-aware escaping (0.1.11) restored that and left the two mechanisms — escape here, sanitize there — to be kept in step by hand forever. Both were reversed in review. What ships is D2/D3 below: the plugin rewrites nothing, and content is either stored verbatim or refused at the gate. D1 is unaffected by any of that and is the only part of the original design that survived intact.

## Decisions

### D1: Fix `to_attr_format` by escaping for the HTML attribute context

`gsub('"', '\"')` is replaced with `CGI.escapeHTML` on the value. The method's job is to emit an HTML attribute list, so the value must be escaped for that context — the previous behavior escaped for a Ruby string literal, which is simply the wrong target language.

**`CGI.escapeHTML`, not `ERB::Util.html_escape`.** An earlier draft specified the latter. Testing it showed why that is wrong for a security primitive: Rails' `html_escape` is a no-op on an `html_safe` string, so `"x\" <a> & q".html_safe` comes back with its quote intact and can still close its own attribute. `CGI.escapeHTML` escapes unconditionally, which is the contract this method needs — its callers build attribute values, never markup.

The method also interpolated attribute **names** verbatim. Escaping cannot defend that position: the characters that split one name into two are whitespace and `=`, which no HTML escaper touches. Names are validated against a conservative pattern instead, and pairs with an invalid name are dropped — a key such as `x onfocus=alert(1) y` has no safe rendering, and any key containing a space was already producing malformed markup.

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

**The contact form is no longer one of its callers, and the two must not be unified.** Under D2 the plugin emits its own attribute pairs verbatim (`cf_attrs`), because there the values are gated at save and a trusted author is entitled to emit an event handler through `field_attributes`. `to_attr_format` keeps escaping unconditionally, because its other callers are plugins and themes handing it data of unknown provenance. Same-looking code, opposite contracts: one has a gate in front of it and one does not.

### D2: Refuse unsafe content at the gate; the plugin rewrites nothing

Nothing the plugin stores is ever rewritten. An author's content is kept exactly as written, or the save is refused and they are told which setting to fix. The renderer escapes nothing, sanitizes nothing, and emits every value verbatim.

Both rewriting strategies were tried and reversed:

- **Escaping** attribute positions is safe but not idempotent — a value re-saved through the editor grows another layer of entities every time — and it leaves the form editor showing something other than what the author typed.
- **Sanitizing** element content silently discards the author's work, with no indication which part went missing or why.

Refusing avoids both, and buys something neither has: *stored content always equals authored content*, which is what makes rendering it verbatim safe. There is one mechanism, at one place, rather than an escaper and a sanitizer that have to be kept in step across a 60-line string-building helper.

Rejection criteria are deliberately narrow — one per HTML context, refusing exactly what can escape that context and nothing more:

| context | where it renders | refused |
|---|---|---|
| **markup** | element content | anything an HTML sanitizer would change |
| **attribute** | inside a double-quoted attribute value | `"` — angle brackets and ampersands are inert here |
| **textarea** | `<textarea>` content, which is RCDATA | `</textarea` — a quote is ordinary prose here and must be accepted |

Narrowness is a requirement, not an optimization. Running a sanitizer over a visitor's message would refuse `Fish & Chips <today>` as "not allowed", which is both wrong and infuriating.

**A value belongs to every context it can actually reach**, which is not always the one it was designed for. Getting this wrong is not a theoretical concern — every hole in the table below was found by re-deriving it against the renderer after the first version of the table was written, and each was a live, reproducible XSS reachable by a role holding `:manage, :plugins` alone:

| position | contexts | note |
|---|---|---|
| `railscf_mail[:previous_html]` / `[:after_html]` | markup | |
| `railscf_mail[:subject]` / `[:subject_answer]` | markup | `mailer.html.erb` is `<h2><%= raw @subject %></h2>` |
| `railscf_mail[:body]` / `[:body_answer]` | markup | rendered with `raw` in the notification e-mail |
| `railscf_form_button[:name_button]` | markup | |
| every `railscf_message` value | markup | joined into `flash[:contact_form]`, which both flash partials render with `raw` |
| `field_options[:template]` | markup + placeholder position | see the note below |
| `label` | markup + attribute | element content in the template; reaches `name=` in the `include_other_option` branch |
| `field_options[:description]` | markup | element content only, once the placeholder rule holds |
| `field_options[:field_class]` | attribute | |
| option `label` | markup + attribute | the `value=` attribute is derived from it by the renderer itself |
| `default_value` | attribute **or** textarea | depends on the field type — paragraph and textarea redisplay it as textarea content |
| `field_options[:field_attributes]` | attribute name + value | JSON; a name that is itself an event handler runs script without escaping anything |
| `recaptcha_site_key` | attribute | the recaptcha gem interpolates it into `data-sitekey="…"` unescaped |
| `values[cid]` (visitor submission) | active markup, **plus** attribute *or* textarea | two sinks: the notification e-mail and the redisplayed form |

Four of these are counter-intuitive enough to be worth stating outright:

1. **The table is only true because the placeholder position is fixed.** The author writes the template too, so it — not the renderer — used to decide the context of everything substituted into it. `<div title="[descr ci]">` relocated a description into a double-quoted attribute; `<div class='[descr ci]'>` relocated it into a *single*-quoted one, where an apostrophe escaped and no rule was looking for one; `<div title="[ci]">` put a whole `<textarea>` element inside an attribute, where neither rule described the position. Adding the attribute rule to `description` addressed the first of those and none of the others, and it only ever worked when the same author wrote both values. So the rule is structural instead: **a template that puts `[ci]`, `[label ci]` or `[descr ci]` inside a tag is refused, for everyone including a grant holder.** Every substituted value is then element content, and every attribute in the emitted markup is one the renderer wrote, with double quotes. `description` needs no attribute rule; `label` and option `label` still carry one, because the renderer itself puts them into attributes.
2. **`default_value`'s context is a function of the field type.** A paragraph redisplays it inside a `<textarea>`, where `"` is prose and `</textarea` is the way out; every other type puts it in a `value=` attribute, where the reverse holds. Judging it by the attribute rule alone admits `</textarea><script>alert(1)</script>`, which contains no quote at all. Sound only because of (1).
3. **An event-handler attribute name escapes nothing.** `onfocus` is a well-formed attribute name carrying a quote-free value. Neither the name-shape check nor the quote check can see it; it simply *is* script. Refused by a blunt `on` prefix, as HTML sanitizers do — a list of known handler names fails open as the platform adds more.
4. **A visitor's value reaches a markup sink as well.** `cama_replace_codes` splices every submitted value into the author's mail body, and the mailer renders it with `raw`. The attribute/textarea split describes the redisplayed form and says nothing about that context, so the visitor gate also refuses active markup — script elements, event-handler attributes and script URLs. Deliberately not a sanitizer: it must not refuse `Fish & Chips <today>`.

**The markup rule is structural as well as differential.** Comparing `sanitize(x)` against the reserialized `x` only sees what the safe list *removed*, and is blind to anything the parser discards first. Two shapes exploit that: a tag whose attribute list never closes is dropped at EOF by both sides, but the browser is not at EOF and finishes the attribute at the next quote in the document; and a tag the parser cannot place is foster-parented away before the sanitizer sees it, then materializes as soon as the surrounding page supplies the context (`<td onmouseover="alert(1)">` inside any table). So a gated value may not leave a tag open, and every tag it writes must survive the parse.

**Structural values are held to an allowlist for everyone**, including an author holding the grant: `cid`, `field_type`, `maxlength`, `required`, a choice field's option list, the JSON shape of `field_attributes`, and the placeholder positions in `template` are generated by the form builder, not typed. A field whose type is `text" onfocus="x` is a corrupt record, not a capability; each of the others is a permanent 500 on every public page carrying the form, from a save the author was told had succeeded. Constraining them is what lets the renderer emit them verbatim alongside everything else.

**The cost of the gate is bounded**, because every gated value costs an HTML parse and both the count and the size arrive from `params`: the field list is capped at 200, a field's option list at 100, and a single gated value at 64 KB. Uncapped, an account holding nothing but `:manage, :plugins` measured 17 s of CPU from 4093 option labels in one request, and 20 s from a single 1 MB template.

One position renders *formatting* markup less than fully: a **dropdown** option label, where a browser drops `<b>` and its neighbours inside `<option>`.

An earlier revision of this document claimed `<option>` is text-only per the HTML specification and that a browser therefore discards any element inside it. **That is false, and it was load-bearing** — it was the stated reason a dropdown option label needed no gating. Checked against Nokogiri's HTML5 parser: `<script>` inside an `<option>` survives parsing and executes, and `<template>` survives as well; only ordinary formatting elements are dropped. So the position is gated exactly like every other one, and the limitation is a rendering nicety rather than a security boundary. Radio and checkbox labels render inside a `<label>` and are unaffected either way.

### D3: Gate on the same permission, checked before the record is touched

Leaving these positions ungoverned preserves the plugins-manager → administrator escalation, which is the most severe half of the report. The trust boundary is the one Camaleon already chose for post content in [#1206](https://github.com/owen2345/camaleon-cms/pull/1206): a role-based bypass, defaulting to administrators.

`AdminFormsController#update` validates **before** it touches the record and returns on the first offender. Ordering matters: an earlier revision called `@form.update(name, slug)` first, so a rejected save still persisted the name and slug while dropping everything else. Nothing is saved either way, so there is no reason to keep walking attacker-controlled input once it has already failed.

The same rule governs the front controller. `validate_to_save_form` refuses a malign submission and returns *immediately*, before reCAPTCHA or any other validation — continuing means a round trip to an external service on input already known to be hostile, and an email-format check that calls `.match` on a value the submitter can simply omit. `FrontController#save_form` then stashes nothing into `flash[:values]`: redisplay is the only reason a submission reaches the page at all, so a submission carrying anything malign is refused whole rather than half-echoed.

**The rejection message must never quote back what it rejected.** Both flash partials render with `raw(flash[...])`. An earlier revision interpolated the author's own field label into the error, which made refusing an injection a way to perform one. Messages name only the controller's own constants — `previous_html`, `template`, `option label` — and the visitor-facing message names no field at all.

**The trust predicate is `Ability#can?(:manage, :contact_form_unfiltered_html)`, not `post_content_unfiltered_html`.** The existing key does not fit: `Ability` defines `:post_content_unfiltered_html` against a `CamaleonCms::PostType`, resolved from `@roles_post_type[:post_content_unfiltered_html]`, and `Post#trusted_for_unfiltered_html?` passes a concrete `post_type` to it. Contact forms are `TermTaxonomy` records with no post type, so there is nothing to pass. Reusing the key would mean inventing a fake post-type argument or reading role meta directly, both of which fork the trust model rather than share it.

**The trust predicate is `Ability#can?(:manage, :contact_form_unfiltered_html)`, not `post_content_unfiltered_html`.** The existing key does not fit: `Ability` defines `:post_content_unfiltered_html` against a `CamaleonCms::PostType`, resolved from `@roles_post_type[:post_content_unfiltered_html]`, and `Post#trusted_for_unfiltered_html?` passes a concrete `post_type` to it. Contact forms are `TermTaxonomy` records with no post type, so there is nothing to pass. Reusing the key would mean inventing a fake post-type argument or reading role meta directly, both of which fork the trust model rather than share it.

`can?(:manage, :contact_form_unfiltered_html)` avoids that and needs no new Camaleon code:



- Admins already satisfy it, because `Ability#initialize` grants `can :manage, :all` for `user.admin?`.
- `client` and every other non-admin role fails it, because `define_manage_rules` only grants `:manage` on keys present and truthy in the role's `_manager_<site_id>` meta.
- It is extensible without further work: `define_manage_rules` ends with a generic loop granting `:manage` on *any* truthy manager key, so a site that later wants to delegate this to a non-admin role can add a `contact_form_unfiltered_html` manager key and it is honored automatically.

So the shipped default is **administrators only**, with an opt-in path that costs nothing now. `Post#trusted_for_unfiltered_html?` supplies the surrounding shape to copy: read `CurrentRequest.user` and `CurrentRequest.site`, return false if either is blank — guarding the site as well, since `Ability#initialize` dereferences it for non-admin users and would otherwise raise mid-save. Failing closed here means a save from a background job, a rake task or the console is treated as untrusted and refused, rather than silently trusted.

The boundary is stated in the spec: `post-content-sanitization` governs `Post#content` per post type; this capability governs contact-form settings site-wide.

**Alternative considered — check at render instead of save.** Rejected: it re-checks on every page view for no benefit, it cannot distinguish who authored the value, and by then the content is already stored — the author has had no chance to fix it, and the only remaining options are the two rewrites D2 rules out.

### D4: Leave the renderer building strings, now that it escapes nothing

`cama_form_element_bootstrap_object` keeps its string-building structure. Under D2 it has no escaping to place, so the argument for restructuring it is weaker than it was under the escaping designs, not stronger: there are no interpolation points that must not be missed.

**Alternative rejected for now — rewrite using `tag`/`content_tag` and `SafeBuffer`.** That is the idiomatic Rails form and would make the markup structurally correct rather than correct by construction. It is also a full rewrite of a 60-line method, inside a security patch, in a repo whose own suite cannot boot. `AGENTS.md` calls for surgical changes. It is now a better-supported follow-up than it was: the regression specs that would protect such a rewrite exist, in Camaleon, and are listed in the follow-ups.

### D5: Release the plugin in the 0.1.x line, not 0.2.0

Strict semver argues for a minor bump: refusing content that previously saved is a breaking behavior change. It is nonetheless released in the 0.1.x line, because Camaleon's gemspec pins `~> 0.1.0` (`>= 0.1.0, < 0.2.0`). A 0.2.0 would not resolve for any existing Camaleon install — including through the git override this change adds — and a security fix nobody can install protects nobody. The behavior changes are documented prominently in the changelog instead, matching how `post-content-sanitization` handled the same tension.

The shipped version is **0.1.12**. `0.1.10` (uniform escaping) and `0.1.11` (context-aware escaping) are tagged and released on GitHub but describe the designs reversed in review; `0.1.12` supersedes both. Neither reached RubyGems, so nobody can have installed them.

This also determines the git-override mechanics: the branch's `version.rb` must satisfy `~> 0.1.0` for Bundler to resolve it at all.

### D6: Git source in all six Gemfiles, reverted after publication

The main `Gemfile` and all five `gemfiles/*.gemfile` gain:

```ruby
gem 'cama_contact_form', git: 'https://github.com/owen2345/cama_contact_form', branch: '<fix branch>'
```

All five matrix gemfiles are covered because both workflows consume them: `current_support.yml` runs `rails_7_1` through `rails_8_1`, `experimental_support.yml` runs `rails_edge` and `rails_8_1`. Omitting any one would leave a matrix leg resolving 0.1.0 from RubyGems and failing the new specs, which would read as a flaky suite rather than a missing override.

The pattern is already documented for host apps in `docs/example_gemfile.rb`, comment included: *"already dependency of main framework, only here to use latest git source"*. Bundler accepts re-declaring a `gemspec`-declared dependency with a source as long as the version constraint still holds — see D5.

This override is temporary and must be reverted to a version constraint once the fix publishes. Until then Camaleon's CI tests against the plugin's git source, which is the accepted cost of writing the regression specs before the fix can be released. The merged state pins `tag: '0.1.12'` rather than a branch: a tag is immutable, so the resolved revision cannot move under CI, whereas the `branch:` form used during development re-resolves on every `bundle update`.

**Resolved.** `cama_contact_form` 0.1.12 is published to RubyGems, so the override is gone from all six Gemfiles and the gemspec carries the requirement directly:

```ruby
s.add_dependency 'cama_contact_form', '~> 0.1.12'
```

Raised from `~> 0.1.0` rather than merely un-pinned. Deleting the six `gem` lines on its own would have restored a constraint whose range still admits 0.1.0 — the vulnerable release — so a host application resolving afresh would have picked up 0.1.12 while one whose lock already named 0.1.0 would have stayed on it, silently. The gemspec is now the only place the version is stated, which is what D5 wanted all along; host applications need nothing in their own `Gemfile`.

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

- **The position table in D2 is the security boundary, and it is maintained by hand.** Because nothing is escaped at the sink, a position missing from that table is not degraded — it is unprotected. Five were missing from the first version of it, each a live XSS. Any future edit to `cama_form_element_bootstrap_object` that interpolates a new value, or moves an existing one into a different context, must add a row. This is the single largest structural weakness of the rejection model and the strongest argument for the D4 rewrite.
- **The git override outlives its purpose.** If the fix publishes and nobody reverts, Camaleon's CI silently keeps testing a git source instead of the released gem. Mitigated by a task and a changelog note; not mitigated structurally.
- **The rename window is genuinely closed after 2.9.3.** If any part of this change slips to a later release while `#1206` ships in 2.9.3, the rename stops being free and must be dropped or given a migration. The two must ship together.
- **`to_attr_format` has unknown external callers.** Escaping changes their output. Any caller currently passing pre-built markup through an attribute value breaks. That is the intended effect, but it will surface as a bug report from a plugin author rather than as a security acknowledgement. Note that it validates attribute *names* only for shape, so a caller passing `{onclick: …}` still emits a live handler — that is the caller's decision to make, and narrowing it would silently break themes that do it deliberately.
- **Refusal is a worse failure mode than rewriting for a legitimate author.** An untrusted author who pastes a curly quote or writes `See our "policy"` in a description is told the save was refused. That is the accepted cost of never rewriting their work, and the reason the criteria are as narrow as they are, but it will generate support questions that silent sanitization did not.
- **The plugin has no test harness.** Its `test/dummy` cannot boot on Rails 8.1, so every regression spec for it lives in Camaleon and runs only through the git override. If the override is reverted before the gem publishes, the plugin half of this change becomes untested.
- **The reporter's access-control step is unverified.** They did not share reproduction steps, and form editing requires `:manage, :plugins` on `master`. If they used a hole that still exists and is not this one, closing these roots does not close their chain. Requesting the steps is tracked as a task.
