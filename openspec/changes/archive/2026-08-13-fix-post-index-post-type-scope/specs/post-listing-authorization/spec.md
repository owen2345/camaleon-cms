## Purpose

Keep the admin post index within the post type the request is authorized for. The index authorizes
`:posts` on the post type named in the URL, so every row it lists must belong to that post type — a
taxonomy filter must narrow that set, never widen it to another post type's content.

## ADDED Requirements

### Requirement: A taxonomy filter cannot escape the authorized post type

The admin post index SHALL keep its result set scoped to the post type named in the URL (the one it
authorized `:posts` on). When a category or tag filter is applied, the listing SHALL be the
intersection of that post type's posts and the taxonomy's posts. A category or tag belonging to a
different post type SHALL NOT cause that other post type's posts to be listed, in any status.

#### Scenario: A cross-post-type category filter leaks nothing

- **WHEN** a user authorized on post type A requests A's post index with a `category` (or `post_tag`)
  filter whose id belongs to post type B, including with `?s=all`
- **THEN** none of post type B's posts are listed

#### Scenario: A same-post-type taxonomy filter still narrows the listing

- **WHEN** a user requests a post type's index filtered by a category or tag of that same post type
- **THEN** the listing shows that post type's posts belonging to the taxonomy
