# frontend-post-listing-eager-loading Specification

## Purpose
Pin how frontend post reads load their associations. Post listings render each post's metas,
categories, tags and its post type's metas, so loading them lazily is an N+1 across the page. A
single `Post.with_eager` `preload` scope, applied by `verify_front_visibility`, batch-loads them for
the listing paths (`the_posts` / `the_contents`). It uses `preload` — not `includes`/`eager_load` — so
a caller that later chains a join or a table-qualified `where` (e.g. `PostDecorator#the_related_posts`
joins `:categories`) does not promote the relation into one multi-way `LEFT OUTER JOIN` that would load
a partial set per post and duplicate rows in `count`/`pluck`. Single-record lookups (`the_post`,
single-post render, `the_next_post`/`the_prev_post`) opt out, so resolving one post does not pay the
listing preloads it never reads.

## Requirements

### Requirement: Frontend post listings eager-load their associations up front

`verify_front_visibility` SHALL apply the `Post.with_eager` scope by default, so a relation returned by
`the_posts` / `the_contents` preloads each post's `metas`, `categories`, `post_tags` and its
`post_type`'s `metas`. Iterating such a listing SHALL NOT issue a per-post query for those
associations.

#### Scenario: A listing loads post metas in one batch

- **WHEN** a frontend listing action (category, post type, or post tag) renders N posts
- **THEN** the listed posts' `metas` are loaded in a single batch query
- **AND** adding more posts to the listing does not add per-post `metas` queries

### Requirement: The listing relation preloads and never promotes to a joined query

`Post.with_eager` SHALL be `preload`-shaped: its associations SHALL appear in `preload_values`, and
`includes_values` / `eager_load_values` SHALL be empty. Chaining a `joins`/`eager_load` or a
table-qualified `where` on one of the preloaded tables SHALL NOT make the relation `eager_loading?`,
so the association still loads whole and pagination `count` does not run over a promoted join.

#### Scenario: A chained category-join filter does not promote the relation

- **WHEN** `Post.with_eager` is chained with `joins(:categories)` and a `term_relationships` filter
- **THEN** the relation is not `eager_loading?`
- **AND** the loaded `categories` association still contains every category, not only the filtered one

### Requirement: Single-record post lookups do not pay the listing preloads

`verify_front_visibility` SHALL accept `eager: false`, and every single-record frontend lookup —
`SiteDecorator#the_post`, single-post render, and `the_next_post`/`the_prev_post` — SHALL use it, so
resolving one post does not preload the listing associations.

#### Scenario: Resolving a single post skips the listing preloads

- **WHEN** `site.the_post(<slug>)` resolves one post
- **THEN** the returned post's `metas` and `categories` associations are not loaded

### Requirement: Category assignment does not create duplicate relationships

`update_categories` SHALL treat the requested category ids as a set, so repeated ids do not create
duplicate `term_relationships` rows that would duplicate a post — and inflate the paginated
`total_entries` — in the category and post-tag listings.

#### Scenario: Repeated category ids assign the category once

- **WHEN** `post.update_categories([id, id])` is called with a repeated id
- **THEN** the post has exactly one `term_relationships` row for that category
