## 1. Branch

- [x] 1.1 Create branch `security/prevent-cross-site-reparenting` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict before writing the fix — ✅ legit; reproduced the post-type re-home, cross-site category reparent, and widget re-point; enumeration in `proposal.md`

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/cross_site_taxonomy_reparenting_spec.rb`: a post type keeps its `site_id` when a `parent_id` naming another site is submitted; a category refuses a `parent_id` naming another site's post type or category; a tag keeps its owning post type; a same-post-type category reparent still succeeds
- [x] 2.2 Add `spec/requests/security/cross_site_widget_assignment_spec.rb`: an assignment keeps its own `sidebar_id`/`widget_id` when the request body submits another site's ids, and still applies `title`/`content` edits
- [x] 2.3 Confirm the reproduction examples fail against the unfixed branch before writing the fix

## 3. Fix

- [x] 3.1 Drop `:parent_id` from `PostTypesController#set_data_term`'s permit (it is the site FK)
- [x] 3.2 Drop `:parent_id` from `PostTagsController`'s create/update permit via a `post_tag_params` helper (it is the owning post-type FK)
- [x] 3.3 In `CategoriesController`, add a `validate_category_parent` before_action on `%w[create update]` that accepts only the post type itself or a category in `@post_type.full_categories`, raising `CanCan::AccessDenied` otherwise; keep `:parent_id` permitted for legitimate hierarchy
- [x] 3.4 Drop `:sidebar_id`/`:widget_id` from `Appearances::Widgets::AssignController#update`'s permit (they are create-time, tenant-scoped FKs)
- [x] 3.5 Confirm the specs from section 2 now pass

## 4. Cover the unchanged paths

- [x] 4.1 Run the term feature specs (`categories`, `tags`, `content_groups`) and confirm legitimate create/update through the UI is unchanged
- [x] 4.2 Run `spec/requests/admin/mass_assignment_spec.rb`, the category `idor_spec`, and the widget field-value spec — green
- [x] 4.3 Run the full `spec/requests/` suite and confirm no authorization/mass-assignment regression

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and `spec/requests/` — green
- [x] 5.2 `bin/rubocop` on touched files only — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry covering H8 and H9: the tenancy FKs, the privilege (a site manager), and what was reachable (re-homing a post type / reparenting a category or tag / re-pointing a widget assignment across sites)
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
