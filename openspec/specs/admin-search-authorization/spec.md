# admin-search-authorization Specification

## Purpose
Ensure the admin global search and the drafts index enforce authorization, so an admin-area user cannot
read content or metadata they have no permission for. Both actions ran on login alone; search must
return only what the caller may manage, and the drafts index must be gated like the post listing it
belongs to.
## Requirements
### Requirement: Admin search returns only results the caller may manage

`AdminController#search` SHALL scope every result kind to the caller's authorized post types. Content
and post-type results SHALL be limited to the post types the caller may list (`can? :posts`). A caller
who holds none of `can? :posts`, `can? :categories` and `can? :post_tags` SHALL receive no results of
any kind.

#### Scenario: A user without content permissions sees no content

- **WHEN** a signed-in user with no post permissions searches content for a term matching an
  unpublished post
- **THEN** that post's title and slug do not appear in the results

#### Scenario: An administrator still searches all content

- **WHEN** an administrator searches content for a term matching a post in any status
- **THEN** the post appears in the results

#### Scenario: A caller with no search abilities gets no results

- **WHEN** a caller who holds none of `can? :posts`, `can? :categories` and `can? :post_tags` searches
- **THEN** the results of every kind are empty

### Requirement: Admin search limits content of a non-administrator to own posts

For a non-administrator, content results SHALL be limited to the caller's own posts on any post type
where the caller lacks `edit_other`.

#### Scenario: A caller without edit_other finds only own posts

- **WHEN** a non-administrator who lacks `edit_other` on a post type searches content
- **THEN** only the caller's own posts of that post type appear in the results

### Requirement: Admin search scopes taxonomy results by taxonomy ability

Category and tag results SHALL be limited to the post types where the caller holds the matching
taxonomy ability (`can? :categories` / `can? :post_tags`). A taxonomy-manager role with no post edit
grants SHALL still find what it manages. Category results SHALL cover every nesting level.

#### Scenario: A taxonomy manager finds the taxonomies they manage

- **WHEN** a user whose role grants only `manage_categories` / `manage_tags` on a post type searches
  categories or tags
- **THEN** that post type's matching categories and tags appear in the results

#### Scenario: Nested categories are found

- **WHEN** a caller with `can? :categories` searches for a category whose direct parent is another
  category
- **THEN** the category appears in the results
- **AND** the cause is that a category belongs to a post type at every level
- **AND** this holds whether its direct parent is the post type or another category

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

