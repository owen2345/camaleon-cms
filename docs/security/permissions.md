# Permissions

Camaleon CMS defines role permissions in two families, both rendered in the User Roles form in the admin UI so site owners can toggle them per-role:

- **Manager permissions** — `CamaleonCms::UserRole::ROLES[:manager]`, stored in a role's `_manager_<site_id>` meta, and site-wide in scope. They become
  abilities through `Ability#define_manage_rules`, which grants `can :manage, <key>` for any key present and truthy in that meta. Checked as
  `can?(:manage, :key)`.
- **Post-type permissions** — `CamaleonCms::UserRole::ROLES[:post_type]`, stored in `_post_type_<site_id>`, and scoped to a list of post type IDs.
  Checked by passing a concrete post type, e.g. `can?(:post_content_unfiltered_html, post_type)`.

Users with the `admin` role satisfy every check through `can :manage, :all` in the Ability class, independently of role meta.

## Manager permissions

- `custom_fields` — Controls who can create/update Custom Field Groups and Custom Fields (write-time permission). This is a manager-level permission
  and should be granted only to trusted users. The permission is checked at write-time by the admin controller so that only permitted roles can
  persist custom field definitions that may contain advanced behavior.
- `contact_form_unfiltered_html` — Permits storing raw HTML anywhere in the bundled contact-form plugin. Without it, a save carrying such content is
  refused rather than rewritten. See [Security: Unfiltered HTML](#security-unfiltered-html) below.

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

Camaleon restricts the HTML a role may store, and two permissions lift that restriction. **They are different permissions with similar names**, they
live in different families, and holding one does not grant the other. Both are introduced in 2.9.3.

They also work differently, which matters when you are deciding who to grant them to. Post content is **sanitized**: an untrusted author's save
succeeds and the disallowed markup is quietly removed. Contact forms are **refused**: an untrusted author's save does not happen at all, and they are
told which setting to fix. Nothing in a contact form is ever rewritten.

| | `post_content_unfiltered_html` | `contact_form_unfiltered_html` |
|---|---|---|
| Family | post-type (`ROLES[:post_type]`) | manager (`ROLES[:manager]`) |
| Role meta | `_post_type_<site_id>` | `_manager_<site_id>` |
| Scope | per post type | all contact forms on the site |
| Checked as | `can?(:post_content_unfiltered_html, post_type)` | `can?(:manage, :contact_form_unfiltered_html)` |
| Without it | `Post#content` is sanitized on save | the save is refused; nothing is stored |
| Covers | `Post#content` | every contact-form value that reaches the page |
| Introduced in | [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) | [#1215](https://github.com/owen2345/camaleon-cms/pull/1215) |

⚠️ **WARNING**: both permissions let a role store markup that is later rendered without escaping — including `<script>`. Because the admin panel is
served from the same origin as the public site, script stored by a holder of either permission executes with the session of any administrator who
views the affected page. Grant them only to users you would be willing to make administrators.

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
editor used to render an absent key as an unchecked box. It now derives the admin role's checkboxes from the role rather than from the meta, which is both
what `can :manage, :all` actually does and what keeps the display correct for keys added later. **No backfill task is needed**, and none should be written:
for the default admin role (`term_group: -1`) that meta is not read by the ability system and not writable through the editor, which refuses to persist it.

The default `editor` and `contributor` roles never receive manager meta at all, and `client` receives an empty set, so no non-admin role holds it after an
upgrade.

### Granting to a custom role

Via the Admin UI:

1. Navigate to Settings → User Roles
2. Edit the desired role
3. For contact forms, check **Allow unfiltered HTML in contact forms** under Manager Permissions
4. For post content, check **Allow unfiltered HTML in post content** under the relevant post type
5. Save the role

Via the Rails console:

```ruby
site = CamaleonCms::Site.first
role = site.user_roles.find_by(slug: 'editor')

# Manager family — contact-form markup settings, all forms on the site
manager_meta = role.get_meta("_manager_#{site.id}", {})
role.set_meta("_manager_#{site.id}", manager_meta.merge(contact_form_unfiltered_html: 1))

# Post-type family — per post type, for Post#content
post_type = site.post_types.find_by(slug: 'post')
pt_meta = role.get_meta("_post_type_#{site.id}", {})
pt_meta[:post_content_unfiltered_html] = (pt_meta[:post_content_unfiltered_html] || []) + [post_type.id]
role.set_meta("_post_type_#{site.id}", pt_meta)
```

As with `select_eval`, the Admin role's checkboxes may appear unchecked in the UI even though the permission is effective — admin access comes from
`can :manage, :all`, not from role meta.

### Background jobs and console usage

Both checks read the acting user and site from `CurrentRequest` and **fail closed**: when either is missing, the caller is treated as untrusted
regardless of any role's permissions — post content is sanitized, and a contact-form save is refused. Saves from background jobs, rake tasks, or the
console therefore get the untrusted treatment by default. To save raw HTML from those contexts, set the request context first, as shown in the
`select_eval` section above:

```ruby
CurrentRequest.user = CamaleonCms::User.find_by(username: 'admin')
CurrentRequest.site = CamaleonCms::Site.first
# ... perform the save ...
CurrentRequest.reset
```

### Auditing

To find roles holding either permission:

```ruby
CamaleonCms::Site.all.each do |site|
  site.user_roles.each do |role|
    manager = role.get_meta("_manager_#{site.id}", {})
    post_type = role.get_meta("_post_type_#{site.id}", {})
    puts "#{site.name}/#{role.slug}: manager=#{manager[:contact_form_unfiltered_html].inspect} " \
         "post_type=#{post_type[:post_content_unfiltered_html].inspect}"
  end
end
```

Neither permission applies retroactively. Revoking a role's access stops future raw saves but leaves previously stored markup untouched — audit
existing post content and contact-form settings after revoking.

This matters more for contact forms than for post content, because the gate runs on save rather than on render: a form saved before 2.9.3, or by a
holder of the permission, keeps rendering whatever it holds until someone saves it again. Re-saving a form as an untrusted author is a way to find out
whether it holds anything the gate would refuse — the save will fail and name the field.
