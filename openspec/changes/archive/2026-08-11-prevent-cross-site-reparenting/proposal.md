## Why

Three admin term controllers and the widget-assign controller exposed foreign keys that carry tenancy
through their mass-assignment permit lists. A post type's `parent_id` **is** its `site_id`
(`alias_attribute`), so a settings manager could `PATCH post_type[parent_id]=<other_site>` and re-home
the post type — with every post, category, tag and field group under it — onto another site's domain
(audit finding **H8**). A category's `parent_id` (its parent category / owning post type) and a tag's
`parent_id` (its owning post type) were reassignable across sites the same way. And a widget
assignment's `sidebar_id`/`widget_id` were mass-assignable from the request body even though the record
is loaded scoped to the current site's sidebar, so a widget manager could re-point their assignment
into another site's sidebar, or at another site's widget, with attacker content (audit finding **H9**).

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A. Reproduced against the unfixed branch: `PATCH
/admin/settings/post_types/:id` with `parent_id=<other_site>` moved the post type's `site_id`; a
category `PATCH` with a cross-site `parent_id` reparented it; a widget-assign `PATCH` carrying
`assign[sidebar_id]`/`[widget_id]` re-pointed the assignment. Every reproduction fails against the
unfixed branch, and a same-post-type category reparent still succeeds.

## What Changes

- **post_types / post_tags** — `parent_id` is dropped from the permit lists. It is the site (post type)
  / owning post type, set from the association on create, and the form submits it only as a hidden
  mirror of the current value, never as a user choice.
- **categories** — `parent_id` is a real hierarchy `<select>`, so it is kept but validated: the
  submitted value must be the post type itself or one of its own categories (`full_categories`, scoped
  to the post type's site and id). Anything else raises `CanCan::AccessDenied`. The validation runs on
  both `create` and `update`.
- **widget assign#update** — `sidebar_id` and `widget_id` are dropped from the permit. They are set
  from the tenant-scoped `@sidebar`/`@widget` on create; reordering (including any move) has its own
  current-site-scoped `sidebar#reorder` action.
- Reproducing request specs for each path, plus a positive case proving in-post-type category
  reparenting still works.

## Out of scope

- **Create-path ownership.** `current_site.post_types.new`, `@post_type.post_tags.new`, and
  `@post_type.categories.new` set the owning FK from the association, and the category validation now
  runs on create too — so no create path is left exposed. This change targets the mass-assignable
  `update`/permit surface the audit flagged.
- **Within-post-type category cycles** (parenting a category under its own descendant) are a
  pre-existing hierarchy concern, not a tenancy one, and are unchanged.
- **H10** (a legitimate `:manage, :users`/settings holder's in-site authority) is a separate policy
  question.
