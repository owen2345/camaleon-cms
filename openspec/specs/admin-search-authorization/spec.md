# admin-search-authorization Specification

## Purpose
Ensure the admin global search and the drafts index enforce authorization, so an admin-area user cannot
read content or metadata they have no permission for. Both actions ran on login alone; search must
return only what the caller may manage, and the drafts index must be gated like the post listing it
belongs to.
## Requirements
### Requirement: Admin search returns only results the caller may manage

`AdminController#search` SHALL scope every result kind to the post types the caller is authorized to
list (`can? :posts`). Content results SHALL be limited to posts within those post types, and — for a
non-administrator — further to the caller's own posts on any post type where they lack `edit_other`.
Post type, category and tag results SHALL be limited to the caller's accessible post types; category
results SHALL cover every nesting level (a category belongs to a post type at every level, regardless
of whether its direct parent is the post type or another category). A caller with no content
permissions SHALL receive no results of any kind.

#### Scenario: A user without content permissions sees no content

- **WHEN** a signed-in user with no post permissions searches content for a term matching an
  unpublished post
- **THEN** that post's title and slug do not appear in the results

#### Scenario: An administrator still searches all content

- **WHEN** an administrator searches content for a term matching a post in any status
- **THEN** the post appears in the results

### Requirement: The drafts index is authorized

`Posts::DraftsController#index` SHALL require `:posts` authorization on the post type before rendering.
A caller lacking that permission SHALL be denied (the standard access-denied redirect), not served the
post type's JSON.

#### Scenario: An unauthorized caller is denied

- **WHEN** a signed-in user without `:posts` on the post type requests the drafts index
- **THEN** the request is denied rather than returning the post type JSON

#### Scenario: An authorized caller is served

- **WHEN** a user authorized on the post type requests the drafts index
- **THEN** the request succeeds

