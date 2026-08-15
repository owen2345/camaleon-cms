# Permissions

Camaleon CMS defines role permissions in two families, both rendered in the User Roles form in the admin UI so site owners can toggle them per-role:

- **Manager permissions** — `CamaleonCms::UserRole::ROLES[:manager]`, stored in a role's `_manager_<site_id>` meta, and site-wide in scope. They become
  abilities through `Ability#define_manage_rules`, which grants `can :manage, <key>` for any key present and truthy in that meta. Checked as
  `can?(:manage, :key)`.
- **Post-type permissions** — `CamaleonCms::UserRole::ROLES[:post_type]`, stored in `_post_type_<site_id>`, and scoped to a list of post type IDs.
  Checked by passing a concrete post type, e.g. `can?(:post_content_unfiltered_html, post_type)`.

Users with the `admin` role satisfy every check through `can :manage, :all` in the Ability class, independently of role meta.

## The gating rule

Every permission on this page is an instance of one rule, and a new security-sensitive capability MUST follow it:

1. **Administrators can do anything.** The `admin` role satisfies every check through `can :manage, :all`, before any role meta is read.
2. **For every other role, an action that presents a security threat is allowed only through a dedicated permission that is off by default.** The permission is never seeded onto a non-admin role, so an existing install reads it as not-granted with no migration; and the check **fails closed** — with no `CurrentRequest` user or site (a background job, a rake task, the console), the caller is treated as untrusted.
3. **A gate is the last resort, not the first.** Where the threat is *content* and that content can be judged, the save-time scan judges it (see the remedy rule below) — a blanket refusal by file type, format or category is wrong there. A dedicated permission is the remedy only where no scan can reach a verdict at all. Uploaded JavaScript is the worked example: it has no safe subset and every dangerous capability is reachable through dynamic construction (`window['fet'+'ch']`, `[]['constructor']['constructor']`), so no static rule decides it and the check fails closed. Uploaded markup is the counter-example: it has a finite grammar, so the parse-based scan decides it and `.html` is deliberately *not* gated by type.

Where an existing permission's holders already possess the capability, extend that permission rather than adding one — a new permission would *revoke* the capability from installs that already granted the old one. `media_unfiltered_upload` covers script uploads for exactly this reason: a holder already skips the scan and could already store them.

The gate is an **authorization** decision, never a proxy for one. A filesystem path, an output filename, a client-supplied flag or a network location can each be walked through by the caller; [#1228](https://github.com/owen2345/camaleon-cms/pull/1228) replaced exactly such a path-based upload exemption with `media_unfiltered_upload` for that reason. Where content can be substituted after the check — a `before_upload` handler rewriting the scanned bytes — the substituted content is re-checked, not trusted because the handler ran. A check that fails *open* (allowing the action when it cannot evaluate the permission) is the bug this rule exists to prevent.

**Adding a new gated capability** — the four documented below are the templates:

1. Add the key to `UserRole::ROLES[:manager]` (site-wide) or `ROLES[:post_type]` (per post type) with `color: 'danger'` and an i18n label/description.
2. Gate the dangerous work behind a predicate that mirrors `Post#trusted_for_unfiltered_html?` or `CamaleonCms::UploaderContentSecurity#cama_trusted_for_unfiltered_upload?`: read `CurrentRequest.user` and `CurrentRequest.site`, return false if either is blank, otherwise ask `CamaleonCms::Ability`, and `rescue StandardError` to false. Check it *before* doing the work.
3. Seed no non-admin role with the key. For a **post-type** permission, also add `next if key == '<key>'` to the Editor post-type seeding in `site_default_settings.rb`, which otherwise grants every post-type key.
4. Ship a spec that reproduces the threat (per `AGENTS.md`) and covers the admin-allowed, non-admin-refused, granted-allowed and no-request-context-refused cases.

The convention is specified as `openspec/specs/security-capability-gating/spec.md`.

## The remedy rule: reject, don't transform

The gating rule says *who* may perform a dangerous action; this rule says what happens when an
untrusted user submits dangerous **content**: the save is **refused with an error naming the
problem** — the content is never sanitized, stripped, escaped-away, or otherwise rewritten
(maintainer decision, 2026-08-13). Four properties follow, and every content gate relies on them:

1. **Stored content always equals authored content.** What the gate admitted is byte-for-byte what
   the author wrote, so the frontend may render it verbatim (`raw post.the_content`, editor and
   field_attrs custom-field values). There is no render-time sanitization anywhere: a transform at
   render would silently mutate a trusted author's work and mask gate regressions.
2. **Refusal is loud.** A sanitizer that silently drops markup surprises the author later and
   invites probing until a payload slips through; a refusal names the field and the remedy (remove
   the markup, or hold the relevant permission).
3. **History is reported, not rewritten.** Content stored before a gate existed is left untouched;
   `rake camaleon_cms:security:scan_content` lists everything today's gates would refuse so an
   operator can clean it up deliberately, and `rake camaleon_cms:security:scan_uploads` does the
   same for files already under the media root.
4. **The save-time decision is the only lever.** Content that passes the gate is stored *and
   served* verbatim. No response header, CSP, `X-Content-Type-Options`, `Content-Disposition`,
   separate media origin or other serving-side control constrains what a stored file does in the
   browser — a trusted user was permitted to store it, so it behaves exactly as they intended.
   This bounds the rule from below as the no-transform clause bounds it from above. The test before
   proposing any control: *would it constrain a trusted user's content?* If yes, it is outside this
   model whatever its merit as general security hygiene.

The pieces that implement the rule:

- **`CamaleonCms::UnsafeMarkup`** (`lib/camaleon_cms/unsafe_markup.rb`) is the shared detector for
  authored markup: one parse, safe-list scrub compared against the parse's own reserialization
  (only genuine removals register), plus structural guards — markup the parser drops or leaves open,
  a translation marker inside a tag, and markup smuggled through an attribute value (a value that
  entity-decodes to a tag-open, which a client-side `data-html` sink would inject). It bounds value
  size (an over-size value is refused, and callers report it with a size-specific message) and yields
  a verdict for mis-encoded input rather than raising. It mirrors the cama_contact_form gate — keep
  the two in parity. Scan the content **the renderer will emit**, not the stored encoding:
  `CustomFieldsRelationship.gate_rejection_reason` decodes every member of a `field_attrs` value's
  JSON (any shape — object, array, nested) before scanning, because the JSON encoder hides `<` behind
  unicode escapes, and the same class-level dispatch backs the `scan_content` audit task so the two
  cannot drift.
- **Gates sit on models** (`Post#reject_untrusted_dangerous_content`,
  `CustomFieldsRelationship#reject_untrusted_dangerous_value`), so no controller path can skip
  them; the admin post save wraps the parent and its field values in one transaction, so a refused
  value rolls the whole save back rather than leaving a half-applied post. Positions the platform
  escapes by default (plain `<%= %>` output of non-markup values) carry no gate — that is the
  platform's normal output encoding, not a remedy.
- **Trust and fail-closed follow the gating rule above**: admins always pass; non-admins pass
  through the dedicated permission (`post_content_unfiltered_html` for a post's content and its
  gated field values); no request context means the gate applies. Trusted server-side pipelines
  opt out explicitly per record (`Post#unfiltered_content!`,
  `CustomFieldsRelationship#unfiltered_value!` — bang enablers with no writers, unreachable by
  mass assignment).
- **Uploads already follow the rule** (`svg-upload-sanitization`, `upload-content-security`: scan
  and refuse, with `media_unfiltered_upload` as the trusted skip).

The rule is codified as a requirement in `openspec/specs/security-capability-gating/spec.md`.

## The admin role

Because administrators can do anything (rule 1 above), the `admin` role is the most powerful grant on a
site. Three properties of it matter to operators:

- **Only an admin may grant or remove it.** Holding the `users` manager permission (`can?(:manage, :users)`)
  lets a role create and edit user accounts and assign roles, but it is **not** a path to superadmin.
  Assigning a user the `admin` role — the role `User#admin?` tests, which maps to `can :manage, :all` — or
  changing the role of a user who is *already* an admin, is permitted only when the acting user is
  themselves an admin. This is enforced server-side in `CamaleonCms::UserDecorator#role_grantor?` and
  applied by `Admin::UsersController#user_params` (the user form also hides the `admin` option, and
  disables the role selector, for anyone who cannot grant it). A non-admin user manager can still assign
  every non-admin role. Pinned by `openspec/specs/admin-role-grant-authorization/spec.md`.
- **Only an admin may edit an admin's account.** The role restriction alone would not close the escalation:
  a `:manage, :users` holder who could reset an admin's password would simply sign in as that admin, and
  one who could repoint the admin's email would hijack a password-reset link. Changing an existing admin's
  password or recovery identifiers (email/username) therefore also requires being an admin. This is
  enforced server-side in `CamaleonCms::UserDecorator#may_edit_credentials?`, applied by
  `Admin::UsersController#user_params` and `#updated_ajax` (the user form likewise disables those inputs
  and hides the change-password action for anyone who cannot use them). A non-admin user manager keeps full
  control of every non-admin account, and of their own — only other admins are off-limits.
- **It is global, not per-site.** `User#admin?` is `role == 'admin'` with no site scope, so a user with the
  `admin` role administers **every** site in the installation — most visibly when `users_share_sites` is
  enabled and all users are shared across sites. Treat granting `admin` as granting site-wide superadmin
  across the whole install, not just the current site. Per-site administration would require a
  per-`(user, site)` role model and is not currently supported.

## Manager permissions

- `custom_fields` — Controls who can create/update Custom Field Groups and Custom Fields (write-time permission). This is a manager-level permission
  and should be granted only to trusted users. The permission is checked at write-time by the admin controller so that only permitted roles can
  persist custom field definitions that may contain advanced behavior.
- `contact_form_unfiltered_html` — Permits storing raw HTML anywhere in the bundled contact-form plugin. Without it, a save carrying such content is
  refused rather than rewritten. See [Security: Unfiltered HTML](#security-unfiltered-html) below.
- `media_unfiltered_upload` — Permits uploading files without the malicious-content scan. Without it, every upload is scanned whatever its source, and
  a file carrying scripts, event handlers, blocked elements or blocked URI schemes is refused rather than cleaned up. See
  [Security: Unfiltered HTML](#security-unfiltered-html) below.

Where enforcement happens
- Write-time enforcement: `CamaleonCms::Admin::Settings::CustomFieldsController` uses CanCan (`authorize! :manage, :custom_fields`) to require the
  `custom_fields` manager permission for create/update/destroy actions. This prevents users without the permission from saving Custom Field Groups
  or fields.
- Render-time behavior: certain field types (notably the `select_eval` field) evaluate stored data when rendering. The project maintains render-time
  behavior for backward compatibility, but write-time restrictions are the primary control: only users with the `custom_fields` permission can create
  or modify fields that might include executable commands. If you need a more restrictive runtime policy, consider auditing/clearing any stored
  `select_eval` commands in the database.

### Security: select_eval Custom Field Type

The `select_eval` custom field type is **restricted due to security concerns** as it can execute arbitrary Ruby code. Starting from version 2.9.2, explicit permission is required to create or modify `select_eval` fields.

**For Administrators:**
- Users with the 'admin' role automatically have full access to all custom field types including `select_eval`
  - This access is granted through `can :manage, :all` in the Ability class, not through role meta
  - Note: The Admin role's "Select Eval" checkbox in the UI will remain unchecked (this is expected behavior)
- Client users are restricted by default

**For Custom Roles:**

To grant `select_eval` permission to a non-admin role:

```ruby
# Via Rails console or application code
role = site.user_roles.find_by(slug: 'editor')
current_meta = role.get_meta("_manager_#{site.id}", {})
role.set_meta("_manager_#{site.id}", current_meta.merge(select_eval: 1))
```

**Via Admin UI:**
1. Navigate to Settings → User Roles
2. Edit the desired role
3. Check the "Select Eval" permission under Manager Permissions
4. Save the role

**Security Implications:**

⚠️ **WARNING**: The `select_eval` field type can execute arbitrary Ruby code. Only grant this permission to **fully trusted users** who understand the security implications.

Example of dangerous usage:
```ruby
# A malicious select_eval command could do:
`rm -rf /` # System command execution
User.destroy_all # Database destruction
ENV['SECRET_KEY_BASE'] # Access to sensitive data
```

**Best Practices:**
- Only grant `select_eval` permission to site administrators or developers
- Regularly audit users with this permission
- Consider removing `select_eval` fields from production sites if not actively needed
- Use alternative field types (select, radio, checkbox) when possible

**For Existing Installations:**

If upgrading from a version prior to 2.9.2, you can use this rake task to ensure admin roles have the `select_eval` permission:

```bash
# Run from your application root
bundle exec rake camaleon_cms:backfill_select_eval_permission
# This task does NOT grant new permissions to admins (they already have all permissions by design via `can :manage, :all`).
# It only corrects the display of the select_eval checkbox for admin roles in the UI, so it appears enabled as expected.
```

This task is idempotent and safe to run multiple times.

**Note:** Custom roles (e.g., 'editor', 'contributor') will need manual permission grants via Rails console or the Admin UI if they require `select_eval` access.

**Background Jobs & Console Usage:**

When creating `select_eval` fields from background jobs or Rails console, you must set the user context:

```ruby
# In a background job or console
user = User.find_by(username: 'admin')
site = Site.first

CurrentRequest.user = user
CurrentRequest.site = site

# Now you can create select_eval fields
group.add_field({ name: 'My Field', slug: 'my_field' }, 
                { field_key: 'select_eval', command: 'my_command' })

# Clean up
CurrentRequest.reset
```

Backfilling existing roles
- If you are upgrading an existing installation to `2.9.2`, see the [migration guide](../upgrading-to-2.9.2.md) for the one-off backfill task and rollout steps.

Security notes
- The `custom_fields` manager permission can allow storing code-like commands (e.g., `select_eval`) 
- Treat `custom_fields` as a high-privilege permission — grant it only to trusted administrators. If you inherit a
  database with pre-existing `select_eval` fields, audit their contents before granting the permission widely

## Security: Unfiltered HTML

Camaleon restricts the HTML a role may store, and three permissions lift that restriction. **They are different permissions with similar names**, they
do not all live in the same family, and holding one does not grant the others. All three are introduced in 2.9.3.

They also work differently, which matters when you are deciding who to grant them to. Post content is **sanitized**: an untrusted author's save
succeeds and the disallowed markup is quietly removed. Contact forms and uploads are **refused**: an untrusted author's save or upload does not happen
at all. Nothing in a contact form or an uploaded file is ever rewritten.

| | `post_content_unfiltered_html` | `contact_form_unfiltered_html` | `media_unfiltered_upload` |
|---|---|---|---|
| Family | post-type (`ROLES[:post_type]`) | manager (`ROLES[:manager]`) | manager (`ROLES[:manager]`) |
| Role meta | `_post_type_<site_id>` | `_manager_<site_id>` | `_manager_<site_id>` |
| Scope | per post type | all contact forms on the site | all uploads on the site |
| Checked as | `can?(:post_content_unfiltered_html, post_type)` | `can?(:manage, :contact_form_unfiltered_html)` | `can?(:manage, :media_unfiltered_upload)` |
| Without it | `Post#content` is sanitized on save | the save is refused; nothing is stored | the upload is refused; nothing is stored |
| Covers | `Post#content` | every contact-form value that reaches the page | every upload, whatever its source |
| Introduced in | [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) | [#1215](https://github.com/owen2345/camaleon-cms/pull/1215) | [#1228](https://github.com/owen2345/camaleon-cms/pull/1228) |

⚠️ **WARNING**: all three permissions let a role publish markup that is later served without escaping — including `<script>`. Because the admin panel
and the media library are served from the same origin as the public site, script stored by a holder of any of them executes with the session of any
administrator who views the affected page or opens the affected file. Grant them only to users you would be willing to make administrators.

### `post_content_unfiltered_html` — raw HTML in post content

Without this permission, `Post#content` is sanitized at save time with `CamaleonRecord.cama_sanitize_translatable`, which strips `<script>`,
`<iframe>`, event-handler attributes such as `onerror`/`onload`, and `javascript:` URLs, while preserving ordinary formatting. With it, content is
stored exactly as submitted.

The permission is granted per post type, so a role may hold it for one post type and not another.

**Defaults:** the `admin` role satisfies the check through `can :manage, :all`. The default `editor` role is explicitly excluded from it during role
seeding — `site_default_settings.rb` skips this key when granting every other post-type permission — so upgrading does not widen anyone's trust.

### `contact_form_unfiltered_html` — raw HTML in contact forms

The bundled contact-form plugin renders every value a form holds **verbatim** — no escaping, no sanitization. What makes that safe is this permission:
without it, a save carrying content that could escape the position it renders in is refused outright, so what is stored always equals what the author
wrote. With it, an author may put markup, event handlers or script anywhere in a form and have visitors receive it exactly as written.

The gate covers every authored value that reaches the page:

| value | refused without the permission when it contains |
|---|---|
| `previous_html`, `after_html` (the markup wrapping a form) | markup rule |
| the mail `subject` and `subject_answer` | markup rule |
| the mail `body` and `body_answer` | markup rule |
| the submit button label | markup rule |
| any response message (`mail_sent_ok`, `invalid_required`, …) | markup rule |
| a field's `template` | markup rule |
| a field's `description` | markup rule |
| a field's `label`, or an option label | markup rule, **or** a `"` |
| a field's `field_class` | a `"` |
| a field's `default_value` | `</textarea` on a paragraph/textarea field; a `"` on any other |
| a field's `field_attributes` | an invalid or event-handler attribute name, `style`, a script URL, or a `"` in a value |
| `recaptcha_site_key` | a `"` |

The **markup rule** refuses a value when a sanitizer would change it, when it leaves a tag open, or when a tag it writes does not survive the parse. The
last two matter because the first is blind to anything the parser discards before the sanitizer runs: `<div class="a" onmouseover="alert(1)" x="` is
dropped at EOF by both sides and compares equal, while a browser — which is not at EOF — finishes the attribute at the next quote in the document; and
`<td onmouseover="alert(1)">x</td>` parses to bare text on its own, then becomes a live cell as soon as anything opens table context around it.

The mail values are included because the mailer renders the subject and the body with `raw`. A response message is included because it is rendered with
`raw` into the public page when a visitor's submission succeeds or fails.

`label` and an option label carry the quote rule because the renderer itself puts both into a double-quoted attribute. `description` does not, because it
can only ever be element content — see the placeholder rule below.

**Four things the permission does not lift:**

- **Structural values.** `cid`, `field_type`, `maxlength`, `required`, a choice field's option list and the JSON shape of `field_attributes` are generated
  by the form editor, not typed, and are held to an allowlist for *everyone*, administrators included. A field typed `text" onfocus="x` is a corrupt
  record, not a capability, and each of the others is a permanent 500 on every public page carrying the form.

- **Where a template may put a placeholder.** A `template` that places `[ci]`, `[label ci]` or `[descr ci]` **inside a tag** is refused for everyone. That
  is what makes the table above true: without it the template decides the HTML context of a value written somewhere else, possibly by someone else. A
  template of `<div class='[descr ci]'>` put a description inside a single-quoted attribute, where an apostrophe escaped and no rule was looking for one;
  `<div title="[ci]">` put a whole `<textarea>` element inside an attribute, where neither the quote rule nor the RCDATA rule described the position. A
  trusted author who wants markup in an attribute writes it literally rather than through a placeholder.

- **A visitor's own submission.** It is refused, never escaped, and refused whole — if any field carries a payload, none of the submission is echoed
  back into the form. No permission changes this; the path is reachable without credentials. A visitor is held to a *narrower* rule than an author,
  because their content reaches two sinks rather than one: the redisplayed form (a double-quoted attribute, or `<textarea>` content) and the notification
  e-mail, which splices every submitted value into the author's body and renders the result with `raw`. For the e-mail the test is script elements, event
  handlers and script URLs — deliberately not a sanitizer, which would refuse ordinary prose: being told "your message contains characters that are not
  allowed" for writing `Fish & Chips <today>` is both wrong and infuriating.
- **Existing content.** Nothing is re-checked retroactively. See *Auditing* below.

The grant is deliberately scoped to contact forms rather than to raw HTML in general. A future feature needing its own escape hatch will introduce its
own permission, so enabling this one never silently authorizes a surface you did not intend.

**Defaults:** administrators hold it, and always did. `Ability#initialize` answers `can :manage, :all` for any user whose role is `admin` and returns
before `_manager_` meta is read at all, so the grant does not depend on that meta being present. Seeding writes the key alongside every other manager key,
but seeding runs once, when the site is created — so on a site created before this release the key is simply absent from the stored meta, and the role
editor used to render an absent key as an unchecked box. It now derives the checkboxes of any role slugged `admin` from the role rather than from the meta,
which is both what `can :manage, :all` actually does and what keeps the display correct for keys added later. **No backfill task is needed**, and none
should be written: that meta is never read for an administrator.

Those checkboxes are also **locked**, and `Admin::UserRolesController` declines to write the metas for such a role — the view and the controller test the
same predicate, `UserRole#permissions_editable?`. Locking only the view would have been worse than leaving it alone: a disabled checkbox is not submitted,
so the next save would have cleared whatever the role had stored. Withholding a permission from a role whose users are administrators is not possible
anyway, so offering the toggle would only invite an edit that silently does nothing.

The default `editor` and `contributor` roles never receive manager meta at all, and `client` receives an empty set, so no non-admin role holds it after an
upgrade.

### `media_unfiltered_upload` — unscanned file uploads

Uploads are served from the site's own origin, and there is no server-enforced extension allowlist: `settings[:formats]` defaults to `'*'` and arrives
as `params[:formats]`, so the client picks its own restriction. What stands between an authenticated uploader and an active file in the site origin is
the content scan, and this permission is what decides whether it runs.

Without the permission every upload is scanned, whatever its source — a browser file, a `data:` payload, a remote download, a private-media file, or a
file already published under `public/`. Nothing is stripped or rewritten; the upload simply fails with `Potentially malicious content found!`.

**The ruleset is chosen by how the stored file will be rendered**, which the output filename's extension determines, because that is the extension the
web server will serve the bytes under. There are three:

- **Markup** (`svg svgz svg.gz html htm xhtml xht shtml xml xsl xslt`) is parsed — as XML, or as HTML for the formats that are not well-formed XML —
  and refused if it carries any attribute whose name begins with `on` (matched case-insensitively, by *shape*, so no list of handler names is involved),
  any of the banned elements (`script`, `foreignObject`, `handler`, `iframe`, `object`, `embed`, `form`, `meta`, `base`, `style`, `link`, `applet`,
  `frameset`, `frame`, `template`, `portal`, `marquee`, `math`), or a dangerous URI scheme. A byte-level pass over the same bytes backs the parse up:
  it strips the NUL/C0 padding and matches the element and handler patterns, so a document that declares a bogus encoding (a `utf-16` `<meta charset>` a
  browser resolves to UTF-8) cannot hide a handler from a parser that re-decoded the bytes differently than the browser will. Every member of a
  compressed upload is decompressed first, under a size ceiling, since compressed bytes are opaque to every rule and a compliant decoder concatenates
  all members.
- **Executable script** (`js mjs cjs wasm swf`) is refused outright rather than scanned. No scan can reach a verdict on JavaScript — see rule 3 of
  the gating rule above — so the check fails closed, and this permission is what lifts it. Its holders skip scanning entirely and could already store
  these files, which is why the capability lives here rather than in a second permission.
- **Everything else** is scanned by the pattern ruleset: `<script>`, event-handler attributes, blocked elements, and dangerous URI schemes —
  `javascript:`, `vbscript:`, or a non-raster `data:` URI such as `data:text/html` or `data:image/svg+xml` (an embedded raster image like
  `data:image/png;base64,…` is allowed, since a browser renders it as an inert bitmap). Its element and handler lists are enumerations and therefore
  incomplete, which is why nothing a browser parses as markup is left to it.

With the permission, none of that runs.

Uploading the same bytes as `x.svg` and as `x.html` is two different questions, and both are asked of an uploader without the permission. Before this
permission existed, a source already under `public/` was exempt from re-scanning on the reasoning that its bytes were already served — which let an SVG
that the SVG ruleset accepted be re-cropped under an `.html` name and served as live markup, unscanned. Authorization now decides, so where the file
sits is irrelevant.

Files stored before these rules are never re-examined and never rewritten. `rake camaleon_cms:security:scan_uploads` lists what today's rules would
refuse, read-only, for an operator to review.

**Defaults:** administrators hold it through `can :manage, :all`, exactly as for `contact_form_unfiltered_html`, and the same reasoning about seeding,
locked checkboxes and the absence of a backfill applies unchanged. `editor`, `contributor` and `client` never receive it. **`manage :media` does not
imply it** — reaching the upload and crop endpoints is a different question from skipping the scan, which is the whole point of the split.

### Granting to a custom role

Via the Admin UI:

1. Navigate to Settings → User Roles
2. Edit the desired role
3. For contact forms, check **Allow unfiltered HTML in contact forms** under Manager Permissions
4. For uploads, check **Allow unscanned media uploads** under Manager Permissions
5. For post content, check **Allow unfiltered HTML in post content** under the relevant post type
6. Save the role

Via the Rails console:

```ruby
site = CamaleonCms::Site.first
role = site.user_roles.find_by(slug: 'editor')

# Manager family — contact-form markup settings (all forms on the site) and unscanned uploads
manager_meta = role.get_meta("_manager_#{site.id}", {})
role.set_meta("_manager_#{site.id}", manager_meta.merge(contact_form_unfiltered_html: 1,
                                                        media_unfiltered_upload: 1))

# Post-type family — per post type, for Post#content
post_type = site.post_types.find_by(slug: 'post')
pt_meta = role.get_meta("_post_type_#{site.id}", {})
pt_meta[:post_content_unfiltered_html] = (pt_meta[:post_content_unfiltered_html] || []) + [post_type.id]
role.set_meta("_post_type_#{site.id}", pt_meta)
```

As with `select_eval`, the Admin role's checkboxes may appear unchecked in the UI even though the permission is effective — admin access comes from
`can :manage, :all`, not from role meta.

### Background jobs and console usage

All three checks read the acting user and site from `CurrentRequest` and **fail closed**: when either is missing, the caller is treated as untrusted
regardless of any role's permissions — post content is sanitized, a contact-form save is refused, and an upload is scanned. Saves and uploads from
background jobs, rake tasks, or the console therefore get the untrusted treatment by default. To save raw HTML or upload an unscanned file from those
contexts, set the request context first, as shown in the `select_eval` section above:

```ruby
CurrentRequest.user = CamaleonCms::User.find_by(username: 'admin')
CurrentRequest.site = CamaleonCms::Site.first
# ... perform the save ...
CurrentRequest.reset
```

### Auditing

To find roles holding any of the three permissions:

```ruby
CamaleonCms::Site.all.each do |site|
  site.user_roles.each do |role|
    manager = role.get_meta("_manager_#{site.id}", {})
    post_type = role.get_meta("_post_type_#{site.id}", {})
    puts "#{site.name}/#{role.slug}: contact_form=#{manager[:contact_form_unfiltered_html].inspect} " \
         "upload=#{manager[:media_unfiltered_upload].inspect} " \
         "post_type=#{post_type[:post_content_unfiltered_html].inspect}"
  end
end
```

No permission applies retroactively. Revoking a role's access stops future raw saves and unscanned uploads but leaves previously stored markup and
already-uploaded files untouched — audit existing post content, contact-form settings and the media library after revoking.

This matters more for contact forms than for post content, because the gate runs on save rather than on render: a form saved before 2.9.3, or by a
holder of the permission, keeps rendering whatever it holds until someone saves it again. Re-saving a form as an untrusted author is a way to find out
whether it holds anything the gate would refuse — the save will fail and name the field.

## Security: Off-site redirect allowlist

Unlike the controls above, this is not a role permission — no user holds it. It is a site- and plugin-level allowlist that governs where the admin
session flows (`login`, `logout`, registration) will send the browser after they run.

By default those flows follow only a **same-host** destination: a relative path, or an absolute `http`/`https` URL whose host matches the request host
(compared case-insensitively per RFC 3986). A caller-supplied `return_to` (URL parameter or cookie), an `after_login`/`user_registered` hook's redirect,
and `login_user`'s explicit `redirect_url` are all held to that rule, so a value such as `return_to=https://evil.example/phish` is dropped in favour of
the flow's safe default — the dashboard, or the login page on logout. That is what closes the open redirect
([#1258](https://github.com/owen2345/camaleon-cms/pull/1258)); a non-`http` scheme that embeds the request host (`javascript://your-host/…`) is refused
for the same reason.

A legitimate off-site redirect — an SSO hand-off to an identity provider, a payment provider's hosted checkout — is permitted in one of two ways, both
**fail closed** (nothing off-site is reachable until you opt a specific host or destination in) and both **`http`/`https` only**.

### Trusting a host (the allowlist)

Add the destination's host to the site's `redirect_allowed_hosts` option — a comma-separated list, hosts compared case-insensitively. Once listed, any
session flow (including a user-supplied `return_to`) may redirect to that host:

```ruby
site = CamaleonCms::Site.first
site.set_option('redirect_allowed_hosts', 'idp.example.com, checkout.stripe.com')
```

A plugin can contribute a host at runtime instead of relying on site configuration, by handling the `safe_redirect_hosts` hook and appending to
`args[:hosts]` — the idiomatic way for an SSO or payment plugin to declare its own provider. Declare the hook in the plugin's `config/config.json` and
append the host in the named helper method:

```json
"hooks": { "safe_redirect_hosts": ["add_trusted_redirect_hosts"] }
```

```ruby
# in the plugin's helper (declared under "helpers" in config.json)
def add_trusted_redirect_hosts(args)
  args[:hosts] << 'idp.example.com'
end
```

Exact host match only — there is no wildcard or subdomain matching; list each host you trust.

### Vouching for a destination (the opt-in)

When the destination host is not known in advance — a per-request checkout URL, say — an `after_login` or `user_registered` hook may vouch for its own
redirect by setting `allow_external_redirect` alongside the `redirect_to`/`redirect_url` it sets:

```ruby
def after_login(args)
  args[:redirect_to] = my_dynamic_checkout_url   # any host
  args[:allow_external_redirect] = true
end
```

This is the one path that follows an off-site host without allowlisting it, so use it only for a destination the plugin has itself constructed and
trusts — **never** one derived from request input, which would re-open the open redirect. It is available only on these server-set hook redirects; a
caller-supplied `return_to` can never opt itself in this way, so it cannot be reached from a crafted URL. (`login_user` exposes the same control as an
`allow_external:` keyword for code that calls it directly.)

A followed off-site redirect is emitted with Rails' `allow_other_host` where the framework supports it (7.0+), so the redirect backstop permits it; a
same-host redirect keeps that backstop as a second layer.

### Auditing

The allowlist is per site. Hook-contributed hosts are added per request and are not stored, so they live in plugin code rather than the database:

```ruby
CamaleonCms::Site.all.each do |site|
  puts "#{site.name}: redirect_allowed_hosts=#{site.get_option('redirect_allowed_hosts', '(none)').inspect}"
end
```

An empty or unset `redirect_allowed_hosts`, with no plugin handling `safe_redirect_hosts` and no hook setting `allow_external_redirect`, is the default
strict same-host posture.
