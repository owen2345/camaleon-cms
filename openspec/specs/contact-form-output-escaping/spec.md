# contact-form-output-escaping Specification

## Purpose

Keep what the bundled `cama_contact_form` plugin renders equal to what its authors and visitors wrote. The name is the one the capability was opened under and no longer describes it: nothing here escapes and nothing sanitizes. Every value the plugin renders reaches the page exactly as written, and safety is enforced at the gate — a value that may not be written is refused before it is stored, so stored content always equals authored content and rendering it verbatim introduces nothing the writer did not put there.

Rewriting content was rejected as the remedy rather than merely not chosen. Escaping is not idempotent, so a definition re-saved through the form editor accumulates another layer of entity references on every pass; sanitizing silently discards an author's work with no indication of what was removed. Both leave the editor displaying something other than what was typed. Refusing the save says so plainly instead, and the refusal is whole — a submission carrying one unsafe value echoes back none of its fields, and a refused save persists no part of the form.

What makes verbatim rendering sound is that each value is judged against the HTML context it actually renders in, and refused only for what can escape that context: a sanitizer comparison for element content, a `"` for an attribute, `</textarea` for RCDATA. Anything broader would refuse ordinary prose — a visitor writing `Fish & Chips <today>` being told their message is not allowed. Because nothing is escaped at the sink, this cuts both ways: a position missing from the gated list is not degraded but unprotected, so any change to the plugin's rendering that interpolates a new value, or moves an existing one into a different context, has to extend that list.

The gate has a deliberate hole in it. `:manage, :contact_form_unfiltered_html` exempts an author from every content rule, because delivering markup, event handlers or script to an anonymous visitor exactly as written is the capability the grant exists to confer; the structural allowlist still applies, since a corrupt `field_type` is not a capability anyone wants. The boundary with its neighbours is drawn by subject, not by mechanism: [`post-content-sanitization`](../post-content-sanitization/spec.md) governs `Post#content` per post type, this capability governs contact-form settings and field options site-wide, and [`html-attribute-escaping`](../html-attribute-escaping/spec.md) governs the shared `Hash#to_attr_format` helper — which the plugin deliberately does not use, because one has a gate in front of it and the other does not.

## Requirements
### Requirement: Contact-form content is stored verbatim or refused, never rewritten

The plugin SHALL NOT rewrite stored or submitted content. Neither escaping nor sanitizing is permitted as a remedy in this capability. Content that may not be written SHALL be refused before it is stored, so every rendered value reaches the page exactly as written.

#### Scenario: A refused save leaves the record untouched
- **WHEN** a save is refused for any reason in this capability
- **THEN** no part of the submitted form SHALL be persisted, including the form's `name` and `slug`
- **AND** the previously stored definition SHALL remain exactly as it was

#### Scenario: Accepted content is stored byte-for-byte
- **WHEN** a save is accepted
- **THEN** every stored value SHALL equal the value submitted, with no escaping, sanitization, or normalization applied

#### Scenario: Rewriting is not a remedy
- **WHEN** content may not be written
- **THEN** the save SHALL be refused and the content SHALL NOT be escaped, because escaping is not idempotent
- **AND** a value re-saved through the form editor would accumulate a further layer of entity references on each pass
- **AND** the content SHALL NOT be sanitized, because sanitizing silently discards an author's work with no indication of what was removed
- **AND** both remedies leave the editor displaying something other than what was typed

### Requirement: Refusal criteria are determined by HTML context

Each value SHALL be judged against the context it renders in, and SHALL be refused only for what can escape that context:

| context | rendered as | refused |
|---|---|---|
| markup | element content | any value an HTML sanitizer would change |
| attribute | inside a double-quoted attribute value | any value containing `"` |
| textarea | `<textarea>` content, which is RCDATA | any value containing `</textarea` |

The criteria SHALL be no broader than this.

#### Scenario: A quote is accepted where it cannot escape
- **WHEN** a visitor submits `He said "hello" & left` into a `paragraph` field
- **AND** the submission fails validation for an unrelated reason
- **THEN** the submission SHALL NOT be refused for its content
- **AND** the `<textarea>` SHALL redisplay that exact text
- **AND** a quote refused in a textarea context would reject the commonest punctuation in a written message

#### Scenario: Angle brackets are accepted in an attribute context
- **WHEN** a visitor submits `Fish & Chips <today>` into a `text` field
- **THEN** the submission SHALL NOT be refused for its content
- **AND** the input's `value` attribute SHALL contain that exact text
- **AND** a sanitizer applied to a textarea or attribute context would refuse this ordinary prose and tell the visitor that their message is not allowed

### Requirement: A value is judged against every context it can reach

A value SHALL be judged against every context it can reach, not only the one it was designed for. A value substituted into an author-controlled template can reach any context that template creates. It SHALL therefore satisfy the attribute rule as well as the markup rule.

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

An author not holding `:manage, :contact_form_unfiltered_html` SHALL be refused a save that has an unsafe value in a gated position. These positions are judged as markup: the keys `:previous_html`, `:after_html`, `:subject`, `:subject_answer`, `:body` and `:body_answer` of `railscf_mail`, `railscf_form_button[:name_button]`, every value under `railscf_message`, and `field_options[:description]`.

#### Scenario: Script in a wrapper is refused
- **WHEN** a user holding `:manage, :plugins` but not the grant saves `previous_html` containing `<script>fetch('/admin/users')</script>`
- **THEN** the save SHALL be refused and nothing SHALL be persisted

#### Scenario: A response message carrying script is refused
- **WHEN** the same user saves a `railscf_message` value containing `<script>alert(1)</script>`
- **THEN** the save SHALL be refused
- **AND** the reason SHALL be that the front controller joins those values into `flash[:contact_form]`
- **AND** the frontend flash partial renders that flash with `raw`, on both the failure and the success path

#### Scenario: Ordinary content and safe formatting are accepted
- **WHEN** the same user saves `previous_html` of `<h2>Get in touch</h2>`, a `label` of `<strong>Your name</strong>`, and a `field_class` of `form-control large`
- **THEN** the save SHALL succeed
- **AND** each value SHALL be stored exactly as written

### Requirement: Field text values are gated in the contexts they render in

An author not holding `:manage, :contact_form_unfiltered_html` SHALL be refused a save that has an unsafe value in a field position. Each position is judged against the contexts listed:

| position | contexts |
|---|---|
| `field_options[:template]` | markup, and placeholder position |
| field `label` | markup, attribute |
| each option `label` | markup, attribute |
| `default_value` | textarea for `paragraph` and `textarea` fields; attribute for every other type |

#### Scenario: A default value that closes its own textarea is refused
- **WHEN** the same user saves a `paragraph` field whose `default_value` is `</textarea><script>alert(1)</script>`
- **THEN** the save SHALL be refused, even though the value contains no double quote

### Requirement: Attribute values are gated in the attribute context

An author not holding `:manage, :contact_form_unfiltered_html` SHALL be refused a save that has an unsafe value in these positions. Each is judged in the attribute context.

| position | contexts |
|---|---|
| `field_options[:field_class]` | attribute |
| `field_options[:field_attributes]` | attribute name and value |
| `recaptcha_site_key` | attribute |

#### Scenario: A reCAPTCHA site key that closes its attribute is refused
- **WHEN** an untrusted author saves a `recaptcha_site_key` containing `"`
- **THEN** the save SHALL be refused
- **AND** the reason SHALL be that the reCAPTCHA gem interpolates the key into `data-sitekey="…"` without escaping

### Requirement: The markup context refuses more than a sanitizer change

The markup context SHALL refuse a value when an HTML sanitizer would change it. It SHALL also refuse a value that leaves a tag open, or that writes a tag which does not survive parsing.

#### Scenario: An open tag or a tag that does not survive parsing is refused
- **WHEN** an untrusted author saves a markup value that leaves a tag open, or that writes a tag which does not survive parsing
- **THEN** the save SHALL be refused
- **AND** the reason SHALL be that the sanitizer comparison cannot reach these two cases, because it sees only what the safe list removed

### Requirement: A new rendered value extends the gated list

Nothing is escaped at the point of rendering, so a position absent from the gated list is not degraded but unprotected. Any change to the plugin's rendering that adds an interpolated value SHALL extend the gated list. This includes a change that moves an existing value into a different context.

#### Scenario: A rendering change extends the list
- **WHEN** a change to the plugin's rendering interpolates a new value or moves an existing value into a different context
- **THEN** the same change SHALL add that position, with its contexts, to the gated list

### Requirement: Field attributes are gated by name and value

`field_options[:field_attributes]` is JSON that the plugin emits verbatim as attribute name/value pairs. An untrusted author SHALL be refused a name that is not a valid HTML attribute name. The author SHALL also be refused a name that denotes an event handler, and a value containing `"`. The event-handler test SHALL be a prefix test on `on`, as HTML sanitizers use.

#### Scenario: An event-handler attribute name is refused
- **WHEN** the same user saves `field_attributes` of `{"onfocus": "alert(1)"}`
- **THEN** the save SHALL be refused, even though the name is well-formed and the value contains no double quote
- **AND** the reason SHALL be that an event-handler name escapes nothing, so neither of the other two rules detects it

#### Scenario: A handler name is detected by prefix, not by a list
- **WHEN** an untrusted author saves a `field_attributes` name that starts with `on`
- **THEN** the save SHALL be refused, whether or not a list of known handler names holds that name
- **AND** the reason SHALL be that a list of known handler names fails open as the platform adds more

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

A submission that has an unsafe value in any field SHALL be refused in its entirety. Nothing SHALL be stored, no mail SHALL be sent, and no field SHALL be echoed back, including the fields whose values were themselves safe. No permission, setting, or field option SHALL exempt it, because this path is reachable without any credentials.

#### Scenario: A safe sibling field is dropped too
- **WHEN** one field of a submission is refused and another carries an ordinary value
- **THEN** neither field SHALL be echoed back
- **AND** the plugin stores a submission into `flash[:values]` and re-renders it only so that the visitor does not lose their input

#### Scenario: An otherwise-valid submission is refused
- **WHEN** a submission would pass every other validation but carries an unsafe value
- **THEN** no response record SHALL be created
- **AND** no mail SHALL be sent

### Requirement: A visitor value is judged by the context its field type renders in

Each visitor value SHALL be judged by the context its field type renders in. The context is textarea for `paragraph` and `textarea`, and attribute for every other type. This matches the rule applied to `default_value`.

#### Scenario: Attribute breakout in a text field
- **WHEN** an unauthenticated visitor submits a `text` field value of `" autofocus onfocus="alert(1)`
- **THEN** the re-rendered page SHALL NOT contain an `onfocus` or `autofocus` attribute on that input
- **AND** the input's `value` attribute SHALL be empty

#### Scenario: Element breakout in a textarea
- **WHEN** the submission carries a `paragraph` value of `</textarea><script>alert(1)</script>`
- **THEN** the re-rendered page SHALL NOT contain a parseable `<script>` element carrying that payload
- **AND** the `<textarea>` SHALL be empty

### Requirement: The visitor refusal is evaluated before other validation

The refusal SHALL be evaluated before any other validation in `validate_to_save_form`, including reCAPTCHA.

#### Scenario: A hostile submission skips the later validations
- **WHEN** a submission carries an unsafe value
- **THEN** the refusal SHALL happen before the reCAPTCHA check
- **AND** no round trip to an external service SHALL be made on input already known to be hostile
- **AND** no email-format check SHALL run, because it raises `NoMethodError` on a value that the submitter can omit
- **AND** nothing is stored either way

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

An author holding `:manage, :contact_form_unfiltered_html` SHALL be subject to none of the content rules above. The author SHALL be able to store markup, event handlers or script in any gated position. An anonymous visitor SHALL receive it exactly as written. The structural allowlist still applies.

#### Scenario: Administrator retains raw markup capability
- **WHEN** an administrator saves `after_html` containing an `<iframe>` or an inline `<script>`
- **THEN** the value SHALL be stored unchanged

#### Scenario: A guest receives the stored script
- **WHEN** a form whose `previous_html` contains an inline `<script>` is rendered on a public page
- **AND** the visitor is unauthenticated
- **THEN** the page SHALL contain that script element as written

### Requirement: Trust is decided by a contact-form ability key

Trust SHALL be decided by `CamaleonCms::Ability#can?(:manage, :contact_form_unfiltered_html)`. The `post_content_unfiltered_html` key used by `post-content-sanitization` SHALL NOT be reused here. By default the predicate resolves to administrators only. A site can delegate it to another role by adding a `contact_form_unfiltered_html` manager key, which `Ability#define_manage_rules` honors through its generic manager-key loop.

#### Scenario: Role delegated the manager key retains raw markup capability
- **WHEN** a non-admin role has a truthy `contact_form_unfiltered_html` key in its `_manager_<site_id>` meta
- **AND** a user with that role saves `previous_html` containing an inline `<script>`
- **THEN** the value SHALL be stored unchanged

#### Scenario: The post-content key is not reused
- **WHEN** a user holds `post_content_unfiltered_html` but not `:manage, :contact_form_unfiltered_html`
- **THEN** the user SHALL be treated as untrusted for contact forms
- **AND** the reason SHALL be that `post_content_unfiltered_html` is defined against a `CamaleonCms::PostType`, and contact forms have no post type

### Requirement: Trust fails closed without context

The trust check SHALL fail closed when the acting user or the current site cannot be resolved. A save that originates from a background job, a rake task or the console SHALL be treated as untrusted.

#### Scenario: Trust fails closed without context
- **WHEN** the acting user or the current site cannot be resolved
- **THEN** the author SHALL be treated as untrusted
- **AND** the save SHALL NOT raise

### Requirement: Legitimate authored markup renders unescaped

Because nothing is rewritten and nothing is escaped, content that passed the gate SHALL render as markup. This preserves the capability the grant is named for.

#### Scenario: Formatting markup in a field label renders
- **WHEN** a field's `label` is `<strong>Your name</strong> <em>(required)</em>`
- **THEN** the rendered label SHALL contain a `<strong>` element reading `Your name` and an `<em>` element reading `(required)`

#### Scenario: A link in a field description renders
- **WHEN** a field's `field_options[:description]` contains `<a href="/privacy">privacy policy</a>`
- **THEN** the rendered page SHALL contain that anchor element

#### Scenario: Site markup in the form wrappers renders
- **WHEN** a form's `previous_html` contains `<h2>Get in touch</h2>`
- **THEN** the rendered page SHALL contain that `<h2>` element

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

### Requirement: A dropdown option label is gated like any other position

Formatting markup in a `dropdown` option label is an exception to markup rendering: a user agent drops `<b>` and its neighbours inside `<option>`. A `dropdown` option label SHALL be gated on exactly the same terms as every other position. The plugin SHALL NOT treat the exception as a guarantee that an `<option>` cannot carry active content.

#### Scenario: A dropdown option label is gated like any other position
- **WHEN** an untrusted author saves a `dropdown` option whose label contains `<script>alert(1)</script>`
- **THEN** the save SHALL be refused

#### Scenario: Active content survives inside an option
- **WHEN** an author holding the grant saves a `dropdown` option whose label contains `<script>alert(1)</script>`
- **THEN** the script SHALL survive parsing and execute, and a `<template>` element SHALL survive too
- **AND** only ordinary formatting elements are discarded
- **AND** a formatting label renders as plain text however it is emitted
- **AND** this limitation is inherent to the element and not a property of this design

### Requirement: The unfiltered-HTML grant is an assignable manager permission

`CamaleonCms::UserRole::ROLES[:manager]` SHALL define a `contact_form_unfiltered_html` key. The role editor SHALL show and assign it, so the trust boundary is not reachable only by hand-editing role meta. The key SHALL be marked as privilege-granting (`color: 'danger'`) alongside its label and description.

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

### Requirement: The grant is scoped to contact forms by name

The grant SHALL NOT be widened to cover other raw-HTML surfaces. A future feature that needs its own escape hatch SHALL introduce a key named for its own subject. Then enabling one permission never silently authorizes a surface that the administrator did not consider.

#### Scenario: A new escape hatch gets its own key
- **WHEN** a future feature needs an escape hatch for another raw-HTML surface
- **THEN** it SHALL introduce a key named for its own subject
- **AND** it SHALL NOT reuse `contact_form_unfiltered_html`

### Requirement: The grant is distinct from the post-content grant

The grant is distinct from `ROLES[:post_type]`'s `post_content_unfiltered_html`. That key is scoped per post type and governs `Post#content` under `post-content-sanitization`. Holding either grant SHALL NOT imply the other.

#### Scenario: The permission does not widen post-content trust
- **WHEN** a user holds `:manage, :contact_form_unfiltered_html` but not `post_content_unfiltered_html` on a post type
- **AND** that user saves a post whose content contains `<script>alert(1)</script>`
- **THEN** the persisted post content SHALL still be sanitized

### Requirement: Hash#to_attr_format escapes attribute values and rejects malformed names

`Hash#to_attr_format` is public API used by plugins and themes that hand it data of unknown provenance. It SHALL continue to escape each value with `CGI.escapeHTML`, not `ERB::Util.html_escape`. It SHALL drop any pair whose key is not a valid HTML attribute name.

#### Scenario: An attribute value cannot close its own attribute
- **WHEN** `to_attr_format` is given a value containing a double quote
- **THEN** the emitted attribute SHALL carry it as an entity reference
- **AND** the element SHALL carry no attribute the caller did not supply

#### Scenario: An html_safe value is escaped
- **WHEN** `to_attr_format` is given an `html_safe` string containing a double quote
- **THEN** the emitted attribute SHALL carry it as an entity reference
- **AND** the reason SHALL be that `ERB::Util.html_escape` is a no-op on an `html_safe` string, which would let such a value close its own attribute

#### Scenario: A malformed attribute name is dropped
- **WHEN** `to_attr_format` is given the key `x onfocus=alert(1) y`
- **THEN** that pair SHALL NOT be emitted
- **AND** the reason SHALL be that no escaper touches the whitespace and `=` that split one name into two

### Requirement: The contact form does not use Hash#to_attr_format

The contact form SHALL NOT use `Hash#to_attr_format`. The two SHALL NOT be unified, because the contact form has a gate in front of its values and the helper does not.

#### Scenario: A granted author emits an event handler through field attributes
- **WHEN** an author holding `:manage, :contact_form_unfiltered_html` saves `field_attributes` of `{"onfocus": "alert(1)"}`
- **THEN** the contact form SHALL emit that attribute as written
- **AND** the reason SHALL be that values are gated at save and the grant entitles the author to emit an event handler

### Requirement: Hash#to_attr_url_format emits a Ruby fragment

`Hash#to_attr_url_format` emits a Ruby fragment rather than HTML. It SHALL NOT be given the HTML escaper, which would corrupt the generated code with entity references. It SHALL emit `value.to_s.inspect`.

#### Scenario: A backslash in a URL attribute round-trips
- **WHEN** `to_attr_url_format` is given a value containing a backslash or a backslash followed by a quote
- **THEN** the emitted fragment SHALL be a syntactically valid Ruby string literal holding that exact value
