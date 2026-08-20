# Design

## D1. Remove vs. validate, per resource

The fix shape follows what each `parent_id` actually means, read off the admin form:

- **post type** (`_form` renders `parent_id` as a `hidden_field`) and **post tag** (same) — `parent_id`
  is the owning FK (`site_id` for a post type via `alias_attribute`; the post type for a tag). It is
  never a user choice; the hidden field only echoes the value the association already set. So it is
  **removed from the permit**. On create the `current_site.post_types.new` / `@post_type.post_tags.new`
  association sets it; on update it is simply not accepted.
- **category** (`_form` renders `parent_id` as a `<select>` of `[[none, @post_type.id]] +
  @post_type.categories`) — `parent_id` is a genuine hierarchy choice. Removing it would break nesting,
  so it is **kept but validated** against the same set the form offers: the post type itself, or a
  category in `@post_type.full_categories` (which is `where(site_id:, post_type_id:)` — scoped to this
  post type's site and id). Anything else is a tampered value and raises `AccessDenied`.

Validating rather than silently coercing means a tampered request is refused wholesale (matching the
`custom-field-group-tenancy` "refuses" behavior), not quietly rewritten.

## D2. Widget assignment: the FKs are create-time, and moves have their own action

`assign#update`'s job is to edit an assignment's `title`/`content`. Its `sidebar_id` (post_parent) and
`widget_id` (visibility) are set when the assignment is created by the `new` action from the
route-scoped `@sidebar` and the looked-up `@widget`. The shipped form submits neither key for a move
(it posts `sidebar_id` only in the URL, which routes through `current_site.sidebars.find`), and
reordering — including moving between sidebars — goes through `sidebar#reorder`, which re-scopes through
`current_site.sidebars`. So the two keys are **removed from the update permit**; nothing legitimate
writes them there, and leaving them let an assignment escape its tenant.

## D3. Create paths were already owner-scoped; the change is on the write surface

The audit rated only the `update`/permit surface exposed. The association constructors set the owning
FK on create, and the category validation is wired to `%w[create update]` so a crafted create cannot
smuggle a cross-site parent either. No legitimate create/update flow changes: the term feature specs
(categories/tags/content groups) and the widget field-value spec pass unmodified.
