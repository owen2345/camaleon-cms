## ADDED Requirements

### Requirement: Visitor-supplied field values are escaped when re-rendered

`Plugins::CamaContactForm::FrontController#save_form` stores the submitted `params[:fields]` into `flash[:values]` whenever validation fails, and the `[forms slug=…]` shortcode renders them back into the form so the visitor does not lose their input. Every such value SHALL be HTML-escaped before interpolation, in every field type that echoes it.

This is the only path in the capability reachable without any credentials, so it SHALL be escaped unconditionally — no permission, setting, or field option may exempt it.

#### Scenario: Attribute breakout in a text field
- **WHEN** an unauthenticated visitor submits a form that fails validation, with a `text` field value of `" autofocus onfocus="alert(1)`
- **THEN** the re-rendered page SHALL NOT contain an `onfocus` attribute on the input
- **AND** the input's `value` attribute SHALL contain the submitted string as text

#### Scenario: Element breakout in a textarea
- **WHEN** the same submission carries a `paragraph` or `textarea` value of `</textarea><script>alert(1)</script>`
- **THEN** the re-rendered page SHALL NOT contain a parseable `<script>` element
- **AND** the `<textarea>` SHALL remain a single well-formed element

#### Scenario: Escaping applies to every echoing field type
- **WHEN** a failing submission carries a breakout payload in each of `text`, `website`, `email`, `paragraph`, and `textarea`
- **THEN** none of the rendered fields SHALL yield an executable attribute or element

#### Scenario: Legitimate input round-trips
- **WHEN** a failing submission carries the value `Fish & Chips <today>`
- **THEN** the re-rendered field SHALL display that exact text to the visitor
- **AND** SHALL NOT display HTML entity references as literal text

### Requirement: Form-definition data fields are escaped at render

Fields that the form editor exposes as plain-text inputs SHALL be HTML-escaped when rendered into the form markup. These are `label`, `default_value`, `field_options[:field_class]`, `field_options[:description]`, the `label` of each `checkboxes`/`radio`/`select`/`dropdown` option, and `railscf_form_button[:name_button]`.

Escaping SHALL apply wherever the value is interpolated, including attribute positions (`value`, `class`) and text positions (button contents, option contents, and substitution of the `[label ci]` and `[descr ci]` placeholders in a field template).

#### Scenario: Script in a field label does not execute
- **WHEN** a user holding `:manage, :plugins` saves a field whose `label` is `<script>alert(1)</script>`
- **AND** a visitor loads a page containing that form's shortcode
- **THEN** the page SHALL NOT contain a parseable `<script>` element originating from the label
- **AND** the label SHALL be visible as literal text

#### Scenario: Attribute breakout via field_class
- **WHEN** a field's `field_options[:field_class]` is `form-control" onmouseover="alert(1)`
- **THEN** the rendered input SHALL NOT carry an `onmouseover` attribute

#### Scenario: Breakout via a select option label
- **WHEN** a `dropdown` field has an option whose `label` is `x" onfocus="alert(1)`
- **THEN** neither the `<option>` element nor its `value` attribute SHALL yield an executable attribute

#### Scenario: Breakout via the submit button name
- **WHEN** `railscf_form_button[:name_button]` contains `</button><script>alert(1)</script>`
- **THEN** the rendered submit control SHALL remain a single well-formed element with no `<script>`

#### Scenario: Escaping survives the template placeholder substitution
- **WHEN** a field uses a custom `template` containing `[label ci]` and `[descr ci]`
- **AND** the `label` and `description` contain HTML-significant characters
- **THEN** the substituted values SHALL be escaped in the final output
- **AND** the template's own markup SHALL be preserved unescaped

### Requirement: Markup-by-contract fields render raw but are sanitized on save

Four values exist to carry site markup and SHALL continue to render unescaped: `railscf_mail[:previous_html]`, `railscf_mail[:after_html]`, `field_options[:template]`, and `field_options[:field_attributes]`. Escaping them would be a functional regression.

Because rendering them raw would otherwise let any holder of `:manage, :plugins` inject script that runs in an administrator's session, `Plugins::CamaContactForm::AdminFormsController#update` SHALL sanitize these four values at save time using `CamaleonRecord.cama_sanitize_translatable` — the entry point `Post#sanitize_content` already uses — unless the saving user is trusted. The check SHALL fail closed, sanitizing, when the user or site context cannot be resolved.

Trust SHALL be decided by `CamaleonCms::Ability#can?(:manage, :contact_form_unfiltered_html)`. The `post_content_unfiltered_html` key used by `post-content-sanitization` SHALL NOT be reused here: it is defined against a `CamaleonCms::PostType` and contact forms have no post type. The predicate above resolves to administrators only by default, and a site MAY delegate it to another role by adding a `contact_form_unfiltered_html` manager key, which `Ability#define_manage_rules` honors through its generic manager-key loop.

The boundary between the two capabilities: `post-content-sanitization` governs `Post#content` per post type; this requirement governs contact-form settings and field options site-wide.

#### Scenario: Untrusted plugins-manager cannot store script in a wrapper
- **WHEN** a user holding `:manage, :plugins` but not `:manage, :contact_form_unfiltered_html` saves `previous_html` containing `<script>fetch('/admin/users')</script>`
- **THEN** the persisted settings SHALL NOT contain a `<script>` element
- **AND** safe markup in the same value SHALL be preserved

#### Scenario: Untrusted plugins-manager cannot store an event handler in a template
- **WHEN** the same user saves a `field_options[:template]` containing `<div onload="alert(1)">[ci]</div>`
- **THEN** the persisted template SHALL NOT contain the `onload` attribute
- **AND** the `[ci]` placeholder SHALL be preserved

#### Scenario: Administrator retains raw markup capability
- **WHEN** an administrator saves `after_html` containing an `<iframe>` or an inline `<script>`
- **THEN** the persisted value SHALL be stored unchanged

#### Scenario: Role delegated the manager key retains raw markup capability
- **WHEN** a non-admin role has a truthy `contact_form_unfiltered_html` key in its `_manager_<site_id>` meta
- **AND** a user with that role saves `after_html` containing an inline `<script>`
- **THEN** the persisted value SHALL be stored unchanged

#### Scenario: Existing legitimate markup keeps rendering
- **WHEN** a form has previously stored `previous_html` containing headings, paragraphs, and links
- **THEN** the rendered page SHALL emit that markup unescaped

#### Scenario: Sanitization fails closed without context
- **WHEN** the saving user or the current site cannot be resolved
- **THEN** the value SHALL be sanitized rather than stored raw
- **AND** the save SHALL NOT raise

#### Scenario: field_attributes cannot inject a second attribute
- **WHEN** `field_attributes` is the JSON `{"data-x": "y\" onfocus=alert(1) z=\""}`
- **THEN** the rendered element SHALL carry `data-x` as a single attribute
- **AND** SHALL NOT carry an `onfocus` attribute

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

#### Scenario: Enabling the permission grants the bypass
- **WHEN** an administrator enables the permission on a custom role
- **AND** a user in that role saves `previous_html` containing an inline `<script>`
- **THEN** the persisted value SHALL be stored unchanged

#### Scenario: The permission does not widen post-content trust
- **WHEN** a user holds `:manage, :contact_form_unfiltered_html` but not `post_content_unfiltered_html` on a post type
- **AND** that user saves a post whose content contains `<script>alert(1)</script>`
- **THEN** the persisted post content SHALL still be sanitized
