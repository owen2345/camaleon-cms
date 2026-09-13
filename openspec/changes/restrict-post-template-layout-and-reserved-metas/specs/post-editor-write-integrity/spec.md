## Purpose

Keep the metas and options an admin post save takes from the request to what the post editor offers and what an author may set, so a request cannot pick an arbitrary rendering template, corrupt engine-maintained state, or publish through `restore` without the publish permission.

## ADDED Requirements

### Requirement: Template and layout choices from non-admins are limited to the offered lists

A post save or draft save by a user who is not an administrator SHALL be refused when it carries a non-blank `meta[template]`, `meta[layout]`, `options[default_template]` or `options[default_layout]` value that is not in the list the post editor offers for the post's type. The offered lists are the current theme's post templates and layouts, as extended by the `post_get_list_templates` and `post_get_list_layouts` hooks. The refusal SHALL name the field, and nothing from the save SHALL be stored: not the post's attributes, its metas, its custom-field values, or its options. A blank value SHALL be accepted. An administrator's values SHALL be stored as written. Values stored before this requirement SHALL NOT be rewritten.

#### Scenario: Non-admin names a template outside the offered list

- **WHEN** an editor updates a published post with `meta[template]` set to an admin view such as `camaleon_cms/admin/settings/site`
- **THEN** the save is refused with an error naming the template field
- **AND** the post's stored template, title and other metas are unchanged, and its public page renders as before

#### Scenario: Non-admin sets a default template while the post type has templates switched off

- **WHEN** a contributor saves a post with `options[default_template]` set to a name the editor does not offer
- **THEN** the save is refused and no option is stored

#### Scenario: Non-admin names a layout outside the offered list

- **WHEN** an editor saves a post with `meta[layout]` set to `camaleon_cms/admin`
- **THEN** the save is refused with an error naming the layout field and nothing is stored

#### Scenario: Offered and blank values are accepted

- **WHEN** a non-admin saves a post whose template is one of the theme's offered templates, whose layout is blank, or whose template comes from the `post_get_list_templates` hook
- **THEN** the save succeeds and the values are stored as submitted

#### Scenario: Administrator values are not restricted

- **WHEN** an administrator saves a post with a template name outside the offered list
- **THEN** the save succeeds and the value is stored as written

#### Scenario: Draft autosave is held to the same lists

- **WHEN** a non-admin's draft save carries a template outside the offered list
- **THEN** the draft save answers with an error naming the field and stores none of the submitted metas or options

### Requirement: Engine-maintained metas and options are never taken from request params

A post save or draft save SHALL be refused, for every user including administrators, when its `meta` params carry a key starting with `_` or one of the engine-maintained counters `visits` and `comments_count`, or when its `options` params carry `status_default` or `draft_status`. The refusal SHALL name the key, and nothing from the save SHALL be stored. Every other `meta` and `options` key SHALL be stored as submitted. The engine's own writes to these keys (trashing a post, counting a visit or a comment, autosaving a draft) SHALL be unaffected.

#### Scenario: A submitted options hash replacement is refused

- **WHEN** an administrator saves a post with `meta[_default]` set to a string
- **THEN** the save is refused with an error naming `_default`
- **AND** the post's options and its public page are unchanged

#### Scenario: A submitted restore status is refused

- **WHEN** a contributor saves a post with `options[status_default]=published`
- **THEN** the save is refused and `status_default` is not stored

#### Scenario: Ecosystem keys keep being stored

- **WHEN** a non-admin saves a post carrying `options[seo_title]`, `options[hide_in_sitemap]` and `meta[product_specifications]`
- **THEN** the save succeeds and each value is stored as submitted

#### Scenario: The engine still maintains its own keys

- **WHEN** a post is trashed and its public page is visited
- **THEN** `status_default` records the status it had and the visit counter increases

### Requirement: Restore returns only a trashed post, and only to a status the user may give it

`restore` SHALL act only on a post whose status is `trash`. For any other post it SHALL change nothing and report that the post is not in the trash. It SHALL restore the stored previous status only when that status is `published`, `pending` or `draft`, and only `published` when the acting user holds the publish permission for the post's type. In every other case the post SHALL return as `pending`.

#### Scenario: A non-publisher cannot publish through restore

- **WHEN** a contributor without the publish permission restores a trashed post whose stored previous status is `published`
- **THEN** the post returns as `pending`

#### Scenario: A publisher restores a published post

- **WHEN** an editor with the publish permission restores a trashed post whose stored previous status is `published`
- **THEN** the post returns as `published`

#### Scenario: Restore does not touch a post outside the trash

- **WHEN** any user restores a post whose status is `pending`
- **THEN** the post's status is unchanged and the response reports that the post is not in the trash

#### Scenario: A non-canonical stored status restores as pending

- **WHEN** a trashed post's stored previous status is missing or not one of `published`, `pending` or `draft`
- **THEN** restore returns the post as `pending`
