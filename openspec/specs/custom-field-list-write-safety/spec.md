# custom-field-list-write-safety Specification

## Purpose
Pin that the custom-fields "list" endpoint, which renders a record's field groups, does not perform its
category write on a GET. The action is read-named and read-shaped — the admin fetches it to re-render
field groups — but it also persists the post's categories, which is state-changing and must sit behind
CSRF protection. Rails exempts GET and HEAD from that protection, so the write is confined to POST —
the one verb on this route that CSRF verification actually covers — while the render stays available
on GET.
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

#### Scenario: A POST performs the category write

- **WHEN** a signed-in user sends `POST /admin/settings/custom_fields/list` with `post_id=<ID>` and a `categories` list of the post type's own categories
- **THEN** the post's categories are set to that list

#### Scenario: A POST ignores categories from another site

- **WHEN** the `categories` list on the POST names a category owned by another site
- **THEN** that category is not added to the post

