# contact-form-output-escaping Specification

## Purpose

Keep what the bundled `cama_contact_form` plugin renders equal to what its authors and visitors wrote. The name is the one the capability was opened under and no longer describes it: nothing here escapes and nothing sanitizes. Every value the plugin renders reaches the page exactly as written, and safety is enforced at the gate — a value that may not be written is refused before it is stored, so stored content always equals authored content and rendering it verbatim introduces nothing the writer did not put there.

Rewriting content was rejected as the remedy rather than merely not chosen. Escaping is not idempotent, so a definition re-saved through the form editor accumulates another layer of entity references on every pass; sanitizing silently discards an author's work with no indication of what was removed. Both leave the editor displaying something other than what was typed. Refusing the save says so plainly instead, and the refusal is whole — a submission carrying one unsafe value echoes back none of its fields, and a refused save persists no part of the form.

What makes verbatim rendering sound is that each value is judged against the HTML context it actually renders in, and refused only for what can escape that context: a sanitizer comparison for element content, a `"` for an attribute, `</textarea` for RCDATA. Anything broader would refuse ordinary prose — a visitor writing `Fish & Chips <today>` being told their message is not allowed. Because nothing is escaped at the sink, this cuts both ways: a position missing from the gated list is not degraded but unprotected, so any change to the plugin's rendering that interpolates a new value, or moves an existing one into a different context, has to extend that list.

The gate has a deliberate hole in it. `:manage, :contact_form_unfiltered_html` exempts an author from every content rule, because delivering markup, event handlers or script to an anonymous visitor exactly as written is the capability the grant exists to confer; the structural allowlist still applies, since a corrupt `field_type` is not a capability anyone wants. The boundary with its neighbours is drawn by subject, not by mechanism: [`post-content-sanitization`](../post-content-sanitization/spec.md) governs `Post#content` per post type, this capability governs contact-form settings and field options site-wide, and [`html-attribute-escaping`](../html-attribute-escaping/spec.md) governs the shared `Hash#to_attr_format` helper — which the plugin deliberately does not use, because one has a gate in front of it and the other does not.

## Requirements
### Requirement: Contact-form content is stored verbatim or refused, never rewritten

The capability retains the name it was opened under. It no longer describes escaping: the plugin
escapes nothing and sanitizes nothing, and every value it renders reaches the page exactly as
written. Safety is enforced at the gate instead — content that may not be written is refused before
it is stored, so stored content always equals authored content and rendering it verbatim introduces
nothing the writer did not put there.

The plugin SHALL NOT rewrite stored or submitted content. Neither escaping nor sanitizing is
permitted as a remedy in this capability: escaping is not idempotent, so a value re-saved through the
form editor accumulates a further layer of entity references on each pass, and sanitizing silently
discards an author's work with no indication of what was removed. Both leave the editor displaying
something other than what was typed.

#### Scenario: A refused save leaves the record untouched
- **WHEN** a save is refused for any reason in this capability
- **THEN** no part of the submitted form SHALL be persisted, including the form's `name` and `slug`
- **AND** the previously stored definition SHALL remain exactly as it was

#### Scenario: Accepted content is stored byte-for-byte
- **WHEN** a save is accepted
- **THEN** every stored value SHALL equal the value submitted, with no escaping, sanitization, or normalization applied

### Requirement: Refusal criteria are determined by HTML context

Each value SHALL be judged against the context or contexts it renders in, and SHALL be refused only
for what can escape that context:

| context | rendered as | refused |
|---|---|---|
| markup | element content | any value an HTML sanitizer would change |
| attribute | inside a double-quoted attribute value | any value containing `"` |
| textarea | `<textarea>` content, which is RCDATA | any value containing `</textarea` |

The criteria SHALL be no broader than this. A sanitizer applied to a textarea or attribute context
would refuse ordinary prose — a visitor writing `Fish & Chips <today>` would be told their message is
not allowed — and a quote refused in a textarea context would reject the commonest punctuation in a
written message.

A value SHALL be judged against **every** context it can reach, not only the one it was designed for.
Where a value is substituted into an author-controlled template, it can reach any context that
template creates, and SHALL therefore satisfy the attribute rule as well as the markup rule.

#### Scenario: A quote is accepted where it cannot escape
- **WHEN** a visitor submits `He said "hello" & left` into a `paragraph` field
- **AND** the submission fails validation for an unrelated reason
- **THEN** the submission SHALL NOT be refused for its content
- **AND** the `<textarea>` SHALL redisplay that exact text

#### Scenario: Angle brackets are accepted in an attribute context
- **WHEN** a visitor submits `Fish & Chips <today>` into a `text` field
- **THEN** the submission SHALL NOT be refused for its content
- **AND** the input's `value` attribute SHALL contain that exact text

#### Scenario: A template may not decide the context of a substituted value
- **WHEN** any author saves a `field_options[:template]` that places `[ci]`, `[label ci]` or `[descr ci]` inside a tag, such as `<div title="[descr ci]">` or `<div class='[label ci]'>`
- **THEN** the save SHALL be refused, for every author including one holding `:manage, :contact_form_unfiltered_html`
- **AND** the reason SHALL be that the placeholder's HTML context would otherwise be decided by the template rather than by the renderer

#### Scenario: A value reaching two contexts must satisfy both
- **WHEN** an untrusted author saves an option `label` of `x" onfocus="alert(1)`
- **THEN** the save SHALL be refused, even though no HTML sanitizer would alter that value
- **AND** the reason SHALL be that the renderer derives the control's `value="…"` attribute from the option label

#### Scenario: A value confined to element content is not held to the attribute rule
- **WHEN** an untrusted author saves a `field_options[:description]` of `He said "hello" to me`
- **THEN** the save SHALL succeed and the description SHALL be stored exactly as written

### Requirement: Every authored value that reaches the page is gated

An author not holding `:manage, :contact_form_unfiltered_html` SHALL be refused a save carrying an
unsafe value in any of these positions, each judged against the contexts listed:

| position | contexts |
|---|---|
| `railscf_mail[:previous_html]`, `railscf_mail[:after_html]` | markup |
| `railscf_mail[:subject]`, `railscf_mail[:subject_answer]` | markup |
| `railscf_mail[:body]`, `railscf_mail[:body_answer]` | markup |
| `railscf_form_button[:name_button]` | markup |
| every value under `railscf_message` | markup |
| `field_options[:template]` | markup, and placeholder position |
| field `label` | markup, attribute |
| `field_options[:description]` | markup |
| `field_options[:field_class]` | attribute |
| each option `label` | markup, attribute |
| `default_value` | textarea for `paragraph` and `textarea` fields; attribute for every other type |
| `field_options[:field_attributes]` | attribute name and value |
| `recaptcha_site_key` | attribute |

The **markup** context SHALL refuse a value when an HTML sanitizer would change it, when it leaves a
tag open, or when any tag it writes does not survive parsing. The last two are not reachable by the
sanitizer comparison, which sees only what the safe list removed.

Because nothing is escaped at the point of rendering, a position absent from this list is not
degraded but unprotected. Any change to the plugin's rendering that introduces a new interpolated
value, or moves an existing one into a different context, SHALL extend this list.

`railscf_message` is included because those values are joined into `flash[:contact_form]` by the
front controller and rendered with `raw` by the frontend flash partial, on both the failure and the
success path. `recaptcha_site_key` is included because the reCAPTCHA gem interpolates it into
`data-sitekey="…"` without escaping.

`field_options[:field_attributes]` is JSON emitted verbatim as attribute name/value pairs. An
untrusted author SHALL be refused a name that is not a valid HTML attribute name, a name denoting an
event handler, and a value containing `"`. An event-handler name escapes nothing — it is a
well-formed name carrying a quote-free value — so neither of the other two rules detects it. The
event-handler test SHALL be a prefix test on `on`, as HTML sanitizers use, rather than a list of
known handler names, which fails open as the platform adds more.

#### Scenario: Script in a wrapper is refused
- **WHEN** a user holding `:manage, :plugins` but not the grant saves `previous_html` containing `<script>fetch('/admin/users')</script>`
- **THEN** the save SHALL be refused and nothing SHALL be persisted

#### Scenario: A default value that closes its own textarea is refused
- **WHEN** the same user saves a `paragraph` field whose `default_value` is `</textarea><script>alert(1)</script>`
- **THEN** the save SHALL be refused, even though the value contains no double quote

#### Scenario: An event-handler attribute name is refused
- **WHEN** the same user saves `field_attributes` of `{"onfocus": "alert(1)"}`
- **THEN** the save SHALL be refused, even though the name is well-formed and the value contains no double quote

#### Scenario: A response message carrying script is refused
- **WHEN** the same user saves a `railscf_message` value containing `<script>alert(1)</script>`
- **THEN** the save SHALL be refused

#### Scenario: Ordinary content and safe formatting are accepted
- **WHEN** the same user saves `previous_html` of `<h2>Get in touch</h2>`, a `label` of `<strong>Your name</strong>`, and a `field_class` of `form-control large`
- **THEN** the save SHALL succeed
- **AND** each value SHALL be stored exactly as written

### Requirement: Structural values are allowlisted for every author

`cid`, `field_type` and `field_options[:maxlength]` are generated by the form builder rather than
typed. They SHALL be validated against an allowlist for **every** author, including one holding
`:manage, :contact_form_unfiltered_html`. A field whose type is `text" onfocus="x` is a corrupt
record, not a capability the grant exists to confer.

Constraining these is what permits the renderer to emit them verbatim alongside everything else.

#### Scenario: An administrator cannot store a malformed field type
- **WHEN** an administrator saves a field whose `field_type` is `text" onfocus="alert(1)`
- **THEN** the save SHALL be refused

#### Scenario: An administrator cannot store a malformed cid
- **WHEN** an administrator saves a field whose `cid` is `c1" onfocus="alert(1)`
- **THEN** the save SHALL be refused

#### Scenario: The values the form builder produces are accepted
- **WHEN** a field is saved with a `cid` of `c17`, a `field_type` of `paragraph` and a `maxlength` of `500`
- **THEN** the save SHALL succeed

### Requirement: Visitor submissions are refused whole, never partially echoed

A submission is stored into `flash[:values]` and re-rendered only so the visitor does not lose their
input. A submission carrying an unsafe value in any field SHALL be refused in its entirety: nothing
SHALL be stored, no mail SHALL be sent, and no field SHALL be echoed back, including the fields whose
values were themselves safe.

Each value SHALL be judged by the context its field type renders in — textarea for `paragraph` and
`textarea`, attribute for every other type — matching the rule applied to `default_value`.

The refusal SHALL be evaluated before any other validation in `validate_to_save_form`, including
reCAPTCHA. Nothing is stored either way, and continuing means a round trip to an external service on
input already known to be hostile, and an email-format check that raises `NoMethodError` on a value
the submitter can simply omit.

This path is reachable without any credentials, so no permission, setting, or field option SHALL
exempt it.

#### Scenario: Attribute breakout in a text field
- **WHEN** an unauthenticated visitor submits a `text` field value of `" autofocus onfocus="alert(1)`
- **THEN** the re-rendered page SHALL NOT contain an `onfocus` or `autofocus` attribute on that input
- **AND** the input's `value` attribute SHALL be empty

#### Scenario: Element breakout in a textarea
- **WHEN** the submission carries a `paragraph` value of `</textarea><script>alert(1)</script>`
- **THEN** the re-rendered page SHALL NOT contain a parseable `<script>` element carrying that payload
- **AND** the `<textarea>` SHALL be empty

#### Scenario: A safe sibling field is dropped too
- **WHEN** one field of a submission is refused and another carries an ordinary value
- **THEN** neither field SHALL be echoed back

#### Scenario: An otherwise-valid submission is refused
- **WHEN** a submission would pass every other validation but carries an unsafe value
- **THEN** no response record SHALL be created
- **AND** no mail SHALL be sent

### Requirement: A refusal never repeats the content it refused

Both the admin and the frontend flash partials render their message with `raw`. A refusal message
SHALL therefore contain no part of the submitted content, and SHALL NOT name a field by its authored
label — otherwise refusing an injection becomes a way to perform one.

The admin message SHALL identify the offending position using the controller's own fixed names only.
The visitor-facing message SHALL name no field at all.

#### Scenario: The admin refusal names the position, not the payload
- **WHEN** a save is refused for any gated position
- **THEN** the flash message SHALL NOT contain any substring of the refused value
- **AND** SHALL identify the position by a fixed name such as `previous_html`, `template` or `option label`

#### Scenario: The visitor refusal quotes nothing
- **WHEN** a visitor's submission is refused
- **THEN** the message SHALL tell them what to remove
- **AND** SHALL NOT contain the submitted value or any field's label

### Requirement: The grant makes content deliverable verbatim

An author holding `:manage, :contact_form_unfiltered_html` SHALL be subject to none of the content
rules above, and SHALL be able to store markup, event handlers or script in any gated position and
have an anonymous visitor receive it exactly as written. That capability is the reason the grant
exists; the structural allowlist still applies.

Trust SHALL be decided by `CamaleonCms::Ability#can?(:manage, :contact_form_unfiltered_html)`. The
`post_content_unfiltered_html` key used by `post-content-sanitization` SHALL NOT be reused here: it is
defined against a `CamaleonCms::PostType`, and contact forms have no post type. The predicate resolves
to administrators only by default, and a site MAY delegate it to another role by adding a
`contact_form_unfiltered_html` manager key, which `Ability#define_manage_rules` honors through its
generic manager-key loop.

The check SHALL fail closed when the acting user or the current site cannot be resolved, so a save
originating from a background job, a rake task or the console is treated as untrusted.

The boundary between the two capabilities: `post-content-sanitization` governs `Post#content` per post
type; this requirement governs contact-form settings and field options site-wide.

#### Scenario: Administrator retains raw markup capability
- **WHEN** an administrator saves `after_html` containing an `<iframe>` or an inline `<script>`
- **THEN** the value SHALL be stored unchanged

#### Scenario: Role delegated the manager key retains raw markup capability
- **WHEN** a non-admin role has a truthy `contact_form_unfiltered_html` key in its `_manager_<site_id>` meta
- **AND** a user with that role saves `previous_html` containing an inline `<script>`
- **THEN** the value SHALL be stored unchanged

#### Scenario: A guest receives the stored script
- **WHEN** a form whose `previous_html` contains an inline `<script>` is rendered on a public page
- **AND** the visitor is unauthenticated
- **THEN** the page SHALL contain that script element as written

#### Scenario: Trust fails closed without context
- **WHEN** the acting user or the current site cannot be resolved
- **THEN** the author SHALL be treated as untrusted
- **AND** the save SHALL NOT raise

### Requirement: Legitimate authored markup renders unescaped

Because nothing is rewritten and nothing is escaped, content that passed the gate SHALL render as
markup. This preserves the capability the grant is named for: formatting in a field label, a link in a
description, and site markup in the form wrappers.

*Formatting* markup in a `dropdown` option label is an exception: a user agent drops `<b>` and its
neighbours inside `<option>`, so such a label renders as plain text however it is emitted. That
limitation is inherent to the element, not a property of this design.

It SHALL NOT be treated as a guarantee that an `<option>` cannot carry active content. `<script>`
inside an `<option>` survives parsing and executes, and `<template>` survives; only ordinary
formatting elements are discarded. A dropdown option label is therefore gated on exactly the same
terms as every other position, and an author holding the grant can put script there and have it run.

#### Scenario: A dropdown option label is gated like any other position
- **WHEN** an untrusted author saves a `dropdown` option whose label contains `<script>alert(1)</script>`
- **THEN** the save SHALL be refused

#### Scenario: Formatting markup in a field label renders
- **WHEN** a field's `label` is `<strong>Your name</strong> <em>(required)</em>`
- **THEN** the rendered label SHALL contain a `<strong>` element reading `Your name` and an `<em>` element reading `(required)`

#### Scenario: A link in a field description renders
- **WHEN** a field's `field_options[:description]` contains `<a href="/privacy">privacy policy</a>`
- **THEN** the rendered page SHALL contain that anchor element

#### Scenario: Markup in a radio option label renders
- **WHEN** a `radio` field has an option whose `label` is `<b>Bold option</b>`
- **THEN** the rendered `<label>` SHALL contain a `<b>` element

#### Scenario: The field template renders as markup with its label substituted
- **WHEN** a field uses a custom `template` containing `[label ci]` and `[ci]`
- **THEN** the template's own markup SHALL be preserved
- **AND** the label SHALL be substituted into it
- **AND** the field's input SHALL be present inside it

#### Scenario: Each field type renders the control it needs
- **WHEN** a form contains a `checkboxes` field and a `dropdown` field
- **THEN** the `checkboxes` field SHALL render inputs of type `checkbox`
- **AND** the `dropdown` field SHALL render a `<select>` element

### Requirement: The unfiltered-HTML grant is an assignable manager permission

`CamaleonCms::UserRole::ROLES[:manager]` SHALL define a `contact_form_unfiltered_html` key, so the trust boundary above is visible and assignable in the role editor rather than reachable only by hand-editing role meta. The key SHALL be marked as privilege-granting (`color: 'danger'`) alongside its label and description.

The grant is scoped to contact forms by name and SHALL NOT be widened to cover other raw-HTML surfaces. A future feature needing its own escape hatch SHALL introduce a key named for its own subject, so that enabling one permission never silently authorizes a surface the administrator did not consider.

It is distinct from `ROLES[:post_type]`'s `post_content_unfiltered_html`, which is scoped per post type and governs `Post#content` under `post-content-sanitization`. Holding either SHALL NOT imply the other.

#### Scenario: Permission appears in the role editor
- **WHEN** an administrator opens the role editor for any role
- **THEN** the manager section SHALL list an unfiltered-HTML permission
- **AND** it SHALL be rendered from `ROLES` without a bespoke view change

#### Scenario: Default roles do not receive the grant
- **WHEN** a site's default roles are seeded
- **THEN** the `editor`, `contributor`, and `client` roles SHALL NOT hold the permission
- **AND** `can?(:manage, :contact_form_unfiltered_html)` SHALL be false for users in those roles

#### Scenario: The admin role receives the grant
- **WHEN** a site's default roles are seeded
- **THEN** the `admin` role's `_manager_<site_id>` meta SHALL include the key, through the existing all-manager-keys seeding
- **AND** no key-specific exclusion SHALL be added to that seeding, which would strip it from administrators

#### Scenario: An administrator's permissions render as held whatever the stored meta says
- **WHEN** the role editor is opened for a role whose slug is `admin`, on a site seeded before the key existed and whose `_manager_` meta therefore omits it
- **THEN** every permission SHALL render as checked, in both the post-type grid and the manager list
- **AND** this SHALL be derived from the role rather than from the meta, so a key added to `ROLES` later needs no data migration to display correctly
- **AND** no backfill task SHALL be introduced for it: seeding runs once at site creation and `Ability` never reads that meta for an administrator

#### Scenario: An administrator's permissions cannot be toggled
- **WHEN** the role editor is opened for a role whose slug is `admin`, whether or not that role is otherwise editable
- **THEN** every permission checkbox SHALL be rendered disabled, the bulk selection actions SHALL be hidden, and the form SHALL state that users in the role hold every permission regardless
- **AND** saving the role SHALL leave its `_post_type_` and `_manager_` metas untouched, since a disabled checkbox is not submitted and writing the submitted set would clear them
- **AND** the view and the controller SHALL decide this from one predicate, so they cannot disagree

#### Scenario: A non-admin role remains editable
- **WHEN** the role editor is opened for an editable role whose slug is not `admin`
- **THEN** its permission checkboxes SHALL be editable and saving SHALL persist the submitted set

#### Scenario: A non-admin role still renders from its own meta
- **WHEN** the role editor is opened for a role whose slug is not `admin`
- **THEN** each permission SHALL render as checked only where that role's stored meta grants it

#### Scenario: Enabling the permission grants the bypass
- **WHEN** an administrator enables the permission on a custom role
- **AND** a user in that role saves `previous_html` containing an inline `<script>`
- **THEN** the persisted value SHALL be stored unchanged

#### Scenario: The permission does not widen post-content trust
- **WHEN** a user holds `:manage, :contact_form_unfiltered_html` but not `post_content_unfiltered_html` on a post type
- **AND** that user saves a post whose content contains `<script>alert(1)</script>`
- **THEN** the persisted post content SHALL still be sanitized

### Requirement: Hash#to_attr_format escapes attribute values and rejects malformed names

`Hash#to_attr_format` is public API used by plugins and themes that hand it data of unknown
provenance, and SHALL continue to escape. It SHALL escape each value with `CGI.escapeHTML`, not
`ERB::Util.html_escape` — the latter is a no-op on an `html_safe` string, which would let such a value
close its own attribute — and SHALL drop any pair whose key is not a valid HTML attribute name, since
no escaper touches the whitespace and `=` that split one name into two.

The contact form SHALL NOT use it. There, values are gated at save and an author holding the grant is
entitled to emit an event handler through `field_attributes`; the two SHALL NOT be unified, because
one has a gate in front of it and the other does not.

`Hash#to_attr_url_format` emits a Ruby fragment rather than HTML and SHALL NOT be given the HTML
escaper, which would corrupt the generated code with entity references. It SHALL emit
`value.to_s.inspect`.

#### Scenario: An attribute value cannot close its own attribute
- **WHEN** `to_attr_format` is given a value containing a double quote
- **THEN** the emitted attribute SHALL carry it as an entity reference
- **AND** the element SHALL carry no attribute the caller did not supply

#### Scenario: A malformed attribute name is dropped
- **WHEN** `to_attr_format` is given the key `x onfocus=alert(1) y`
- **THEN** that pair SHALL NOT be emitted

#### Scenario: A backslash in a URL attribute round-trips
- **WHEN** `to_attr_url_format` is given a value containing a backslash or a backslash followed by a quote
- **THEN** the emitted fragment SHALL be a syntactically valid Ruby string literal holding that exact value

