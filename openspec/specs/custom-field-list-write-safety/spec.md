# custom-field-list-write-safety Specification

## Purpose
Pin that the custom-fields "list" endpoint, which renders a record's field groups, does not perform its
category write on a GET. The action is read-named and read-shaped — the admin fetches it to re-render
field groups — but it also persists the post's categories, which is state-changing and must sit behind
CSRF protection. Rails exempts GET and HEAD from that protection, so the write is confined to POST —
the one verb on this route that CSRF verification actually covers — while the render stays available
on GET. Because the action also carries no role `before_action`, the capability additionally pins that
it authorizes the caller against the record it resolves, so neither the render nor the write is exposed
to a signed-in user without rights on that post or post type.
## Requirements
### Requirement: The custom-fields list category write requires a CSRF-verified POST

`Admin::Settings::CustomFieldsController#list` SHALL persist a post's categories (via
`update_categories`) only on a POST request — not merely a non-GET one, because Rails' CSRF
verification exempts HEAD exactly like GET. A GET or HEAD SHALL render the field groups for the
resolved record without mutating it, so that a cross-site request that carries the SameSite=Lax auth
cookie but no CSRF token cannot change or delete a post's category relationships. The route SHALL
accept POST so a legitimate, CSRF-verified caller can still perform the write.

#### Scenario: A GET does not change a post's categories

- **WHEN** a signed-in user sends `GET /admin/settings/custom_fields/list?post_id=<ID>` with no `categories` parameter
- **THEN** the post's category relationships are unchanged

#### Scenario: A HEAD does not change a post's categories

- **WHEN** a signed-in user sends `HEAD /admin/settings/custom_fields/list?post_id=<ID>` (HEAD is CSRF-exempt like GET)
- **THEN** the post's category relationships are unchanged

#### Scenario: A GET renders only the existing post's own categories' field groups

- **WHEN** a signed-in user sends `GET /admin/settings/custom_fields/list?post_id=<ID>&categories[]=<OTHER>` for an existing post that is not assigned category `OTHER`
- **THEN** the rendered field groups are those of the post's own saved categories only, not category `OTHER`'s — the read-only verb does not union the request's `categories` into the render

#### Scenario: A POST performs the category write

- **WHEN** a signed-in user sends `POST /admin/settings/custom_fields/list` with `post_id=<ID>` and a `categories` list of the post type's own categories
- **THEN** the post's categories are set to that list

#### Scenario: A POST ignores categories from another site

- **WHEN** the `categories` list on the POST names a category owned by another site
- **THEN** that category is not added to the post

### Requirement: The custom-fields list endpoint authorizes the caller against the resolved record

`Admin::Settings::CustomFieldsController#list` carries no role `before_action` and is reachable by any
signed-in user, so it SHALL authorize the caller against the record it resolves before rendering or
writing: `:update` on the post when `post_id` names an existing post — covering both the GET/HEAD render
of that post's custom-field values and the POST category write — and `:create_post` on the post type for
the new-post render branch. A caller who lacks the required ability SHALL be denied, with neither the
field groups rendered nor the categories changed.

#### Scenario: A user who cannot update the post is denied

- **WHEN** a signed-in user without `:update` on the post sends `#list` with that `post_id` (by GET or POST)
- **THEN** the request is denied, and the post's categories are unchanged

#### Scenario: A user who cannot create posts of the type is denied the new-post render

- **WHEN** a signed-in user without `:create_post` on the post type sends `#list` with only `post_type`
- **THEN** the request is denied

