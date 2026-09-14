## MODIFIED Requirements

### Requirement: Template and layout choices from non-admins are limited to the offered lists

A post save or draft save by a user who is not an administrator SHALL be refused when it carries a non-blank `meta[template]`, `meta[layout]`, `options[default_template]` or `options[default_layout]` value that is not in the list the post editor offers for the post's type. The offered lists are the current theme's post templates and layouts, as extended by the `post_get_list_templates` and `post_get_list_layouts` hooks. An offered entry's value SHALL be derived the way the editor's select derives it, so every entry shape the select renders (a plain name, a `[label, value]` pair, a pair followed by HTML attributes, a name followed by HTML attributes, a grouped list) is accepted when chosen; a list given as pre-rendered option markup SHALL offer nothing but blank, without raising. The refusal SHALL name the field, and nothing from the save SHALL be stored: not the post's attributes, its metas, its custom-field values, or its options. A blank value SHALL be accepted. An administrator's values SHALL be stored as written. Values stored before this requirement SHALL NOT be rewritten.

#### Scenario: Non-admin names a template outside the offered list

- **WHEN** an editor updates a published post with `meta[template]` set to an admin view such as `camaleon_cms/admin/settings/site`
- **THEN** the save is refused with an error naming the template field
- **AND** the post's stored template, title and other metas are unchanged, and its public page renders as before

#### Scenario: Non-admin sets a default template outside the offered list

- **WHEN** a contributor saves a post with `options[default_template]` set to a name the editor does not offer
- **THEN** the save is refused and no option is stored

#### Scenario: Non-admin names a layout outside the offered list

- **WHEN** an editor saves a post with `meta[layout]` set to `camaleon_cms/admin`
- **THEN** the save is refused with an error naming the layout field and nothing is stored

#### Scenario: Offered and blank values are accepted

- **WHEN** a non-admin saves a post whose template is one of the theme's offered templates, whose layout is blank, or whose template comes from the `post_get_list_templates` hook
- **THEN** the save succeeds and the values are stored as submitted

#### Scenario: Every option shape the editor renders is accepted

- **WHEN** a hook offers a template as `['Landing', 'template_landing', { 'data-x' => '1' }]` or as `['template_y', { class: 'y' }]` and a non-admin saves a post choosing `template_landing` or `template_y`
- **THEN** the save succeeds and the chosen value is stored

#### Scenario: A pre-rendered option list offers nothing

- **WHEN** a hook replaces the template list with a string of option markup and a non-admin saves a post with a non-blank template
- **THEN** the save is refused naming the template field, and a blank template is accepted

#### Scenario: Administrator values are not restricted

- **WHEN** an administrator saves a post with a template name outside the offered list
- **THEN** the save succeeds and the value is stored as written

#### Scenario: Draft autosave is held to the same lists

- **WHEN** a non-admin's draft save carries a template outside the offered list
- **THEN** the draft save answers with an error naming the field and stores none of the submitted metas or options

### Requirement: Engine-maintained metas and options are never taken from request params

A post save or draft save SHALL be refused, for every user including administrators, when its `meta` params carry a key starting with `_` or one of the engine-maintained counters `visits` and `comments_count`, or when its `options` params carry `status_default` or `draft_status`. Keys SHALL be matched case- and surrounding-space-insensitively (the store resolves a meta key that way). A `meta` or `options` key that is not an ASCII word (letters, digits, `_`, `-` and `.`) SHALL be refused for every user, naming the key, because the store resolves keys under database collations that also fold accents and compatibility variants, which no request-side folding reproduces. A `meta` or `options` param that is not a set of fields (for example an array of pairs) SHALL be refused before anything is written. The refusal SHALL name the key, and nothing from the save SHALL be stored. Every other `meta` and `options` key SHALL be stored as submitted. The engine's own writes to these keys (trashing a post, counting a visit or a comment, autosaving a draft) SHALL be unaffected.

#### Scenario: A submitted options hash replacement is refused

- **WHEN** an administrator saves a post with `meta[_default]` set to a string
- **THEN** the save is refused with an error naming `_default`
- **AND** the post's options and its public page are unchanged

#### Scenario: A submitted restore status is refused

- **WHEN** a contributor saves a post with `options[status_default]=published`
- **THEN** the save is refused and `status_default` is not stored

#### Scenario: A non-hash meta or options container is refused

- **WHEN** a save carries `meta` or `options` as an array of pairs rather than a set of fields
- **THEN** the save is refused before anything is written, rather than storing the pairs or raising

#### Scenario: A key that is not an ASCII word is refused

- **WHEN** an editor saves a post with `meta[témplate]` or `meta[＿default]`, or an administrator saves one with `meta[vísits]`
- **THEN** the save is refused with an error naming the key and nothing is stored

#### Scenario: Ecosystem keys keep being stored

- **WHEN** a non-admin saves a post carrying `options[seo_title]`, `options[hide_in_sitemap]` and `meta[product_specifications]`
- **THEN** the save succeeds and each value is stored as submitted

#### Scenario: The engine still maintains its own keys

- **WHEN** a post is trashed and its public page is visited
- **THEN** `status_default` records the status it had and the visit counter increases

### Requirement: A post type's default template and layout options are held to the offered lists

A save of a post type's `meta[default_template]` or `meta[default_layout]` by a user who is not an administrator SHALL be refused unless the value is blank or one the post editor offers, because a post whose own template or layout is blank falls back to the post type's option and the frontend renders it. When the post type is being created, the offered lists SHALL be computed for the post type under creation, as the create form computed them. The refusal SHALL name the field, and the option SHALL NOT be stored. An administrator's value SHALL be stored as written.

#### Scenario: Non-admin sets a post type default template outside the offered list

- **WHEN** a non-admin settings manager saves a post type with `meta[default_template]` set to an admin view
- **THEN** the save is refused with an error naming the field and the option is not stored

#### Scenario: Non-admin creates a post type with an offered default template

- **WHEN** a non-admin settings manager creates a post type with `meta[default_template]` set to a value a `post_get_list_templates` hook offers by reading the post type it is handed
- **THEN** the post type is created with that option stored

#### Scenario: Administrator sets a post type default template freely

- **WHEN** an administrator saves a post type with a `meta[default_template]` outside the offered list
- **THEN** the option is stored as written

### Requirement: Restore returns only a trashed post, and only to a status the user may give it

`restore` SHALL act only on a post whose status is `trash`. For any other post it SHALL change nothing and report that the post is not in the trash. It SHALL restore the stored previous status only when that status is `published`, `pending`, `draft` or the `draft_child` autosave buffer, and only `published` when the acting user holds the publish permission for the post's type. In every other case the post SHALL return as `pending`. A create or update SHALL accept a submitted `post[status]` only when it is exactly one of the statuses the editor offers (`published`, `pending`, `draft`) and SHALL refuse any other value, naming the field, so no variant spelling reaches the column. A blank or absent status on update SHALL leave the post's current status unchanged (a draft being saved with no status is promoted through the publish rule); on create it SHALL take the column default. The same publish rule SHALL apply to every status a create or update would give a post, so a user without the publish permission cannot reach `published` by omitting the status either.

#### Scenario: A non-publisher cannot publish through restore

- **WHEN** a contributor without the publish permission restores a trashed post whose stored previous status is `published`
- **THEN** the post returns as `pending`

#### Scenario: A non-publisher cannot publish by omitting the status on create or update

- **WHEN** a contributor without the publish permission creates a post with no status, or updates a draft with a blank status
- **THEN** the post is saved as `pending`, not `published`

#### Scenario: A status outside the editor's set is refused

- **WHEN** a contributor creates a post with `post[status]=Published`, or an editor updates one with `post[status]` set to `published ` or to a script payload
- **THEN** the save is refused with an error naming the status field and nothing is stored

#### Scenario: A blank status on update keeps the current status

- **WHEN** an editor updates a published post with `post[status]` submitted empty
- **THEN** the post stays `published`
- **AND** updating a draft with an empty status promotes it through the publish rule, as omitting the status does

#### Scenario: A publisher restores a published post

- **WHEN** an editor with the publish permission restores a trashed post whose stored previous status is `published`
- **THEN** the post returns as `published`

#### Scenario: A trashed autosave buffer is restored as a buffer

- **WHEN** a trashed post whose stored previous status is `draft_child` is restored
- **THEN** it returns as `draft_child`, not a standalone post

#### Scenario: Restore does not touch a post outside the trash

- **WHEN** any user restores a post whose status is `pending`
- **THEN** the post's status is unchanged and the response reports that the post is not in the trash

#### Scenario: A non-canonical stored status restores as pending

- **WHEN** a trashed post's stored previous status is missing, unreadable, or not one of `published`, `pending`, `draft` or `draft_child`
- **THEN** restore returns the post as `pending` without raising

## ADDED Requirements

### Requirement: A refused save is decided before the save hooks and shown without re-authorizing

The post save's request check SHALL run before the `create_post` and `update_post` hooks are dispatched, so a hook cannot write to the post before the save is refused. A refused update SHALL re-render the edit form with the refusals and the submitted values, using the authorization already granted for the request; it SHALL NOT re-authorize the post after the submitted attributes are assigned to it.

#### Scenario: A hook writing on save runs only for an accepted save

- **WHEN** an `update_post` hook stores an option on the post and an editor's update is refused for an unoffered template
- **THEN** the hook does not run and the option is not stored

#### Scenario: A user whose right depends on the post's status sees the refusal

- **WHEN** a user whose update right rests on the post being published updates that post with `post[status]=pending` and an unoffered `meta[template]`
- **THEN** the response is the edit form showing the refusal, not an authorization error

### Requirement: Creating a post from a new-post draft removes the author's buffer

When a create request names the draft buffer it was composed from, the current user's own parentless draft buffer of that post type with that id SHALL be destroyed once the post is created. A buffer belonging to another user, under a parent post, or of another post type SHALL NOT be touched.

#### Scenario: The buffer is destroyed on create

- **WHEN** an editor autosaves a new post (creating a parentless buffer) and then creates the post with the form naming that buffer
- **THEN** the post exists and the buffer is gone

#### Scenario: Another user's buffer is untouched

- **WHEN** the create request names a parentless buffer that belongs to another user
- **THEN** the post is created and that buffer remains

### Requirement: Stored values today's write rules would refuse are reported

The `camaleon_cms:security:scan_content` task SHALL list every post whose stored `template`, `layout`, `default_template` or `default_layout` is not blank and not a view file of its site's current theme (naming the post and the value, and noting that a plugin hook may still offer it), every post and post type whose options row is not a JSON object, and every post whose summary the content scan would refuse. The task SHALL modify nothing, and one unreadable record SHALL NOT end the scan.

#### Scenario: A post pointing at an admin view is listed

- **WHEN** the task runs while a post's stored `template` names `camaleon_cms/admin/settings/site`
- **THEN** the output names the post and the value

#### Scenario: A post whose options row is not an object is listed

- **WHEN** the task runs while a post's `_default` meta holds a string
- **THEN** the output names the post and says its options could not be read
- **AND** the scan continues to the posts after it

#### Scenario: A summary the scan would refuse is listed

- **WHEN** the task runs while a post's `summary` meta contains a script element
- **THEN** the output names the post and says its summary would be rejected

#### Scenario: A post with a theme template is not listed

- **WHEN** the task runs while a post's stored `template` names one of the theme's `template_*` views
- **THEN** the output does not name that post
