## Purpose

Association traversals return correctly-typed targets and never raise for valid data: `owner` readers work on every supported user model, and records loaded through scoped collections keep their real `parent`/`owner` targets.

## Requirements

### Requirement: Owner associations never raise and return the owning user

`owner` on `CamaleonCms::TermTaxonomy` (and its subclasses), `CamaleonCms::PostType`,
`CamaleonCms::PostTag`, and `CamaleonCms::Widget::Main` SHALL be readable without
`ActiveRecord::InverseOfAssociationNotFoundError` on every supported user model — including host
apps configuring a custom `user_model` — returning the owning user record or `nil`.
`TermTaxonomyDecorator#the_owner` SHALL return the owner again instead of swallowing the raise
into `nil`.

#### Scenario: Reading a category's owner

- **WHEN** a category row's `user_id` points at an existing user
- **THEN** `category.owner` returns that user and `category.decorate.the_owner` returns the
  decorated user

#### Scenario: Owner reflections are valid

- **WHEN** the `owner` association of `Category`, `PostType`, `PostTag`, or `Widget::Main` is
  accessed on a new record
- **THEN** no `InverseOfAssociationNotFoundError` is raised

### Requirement: Records loaded through site.nav_menu_items keep their real parent

`NavMenuItem#parent` SHALL reference the item's `NavMenu` (via `parent_id`) even when the record
was loaded through `Site#nav_menu_items` (which joins by `term_group`); the association load
SHALL NOT overwrite `parent` with the `Site`. The admin nav-menu-item custom-fields form relies
on this to show the menu's field groups rather than every group in the site.

#### Scenario: Parent of a site-loaded menu item is its menu

- **WHEN** a nav menu item is loaded via `site.nav_menu_items`
- **THEN** `item.parent` is the item's `NavMenu`

### Requirement: Drafts expose their author through owner and their post through parent

`Post#drafts` SHALL set each draft's `parent` inverse to the owning post, and `draft.owner` SHALL
remain the draft's author user — loading drafts through the association SHALL NOT retarget
`owner` at the parent `Post`.

#### Scenario: Draft author survives association loading

- **WHEN** a draft is loaded via `post.drafts`
- **THEN** `draft.owner` is the author user (or `nil`), never a `Post`
- **AND** `draft.parent` is the owning post without an extra query

### Requirement: Category and tag writers reset through-proxies so post-write reads reflect the database

The `CategoriesTagsForPosts` writers (`update_categories`, `update_tags`, `assign_category`,
`unassign_category`) mutate `term_relationships` directly, which does not invalidate an already-loaded
`categories` / `post_tags` / `term_relationships` proxy — and frontend reads preload `categories` via
`with_eager`, so the proxy is routinely loaded before a write. Each writer SHALL reset those proxies
before it snapshots or recounts, so `post.categories` / `post.the_tags`, their published counts, and
`term_relationships` reflect the database after the write rather than a stale in-memory target.

#### Scenario: A removed tag is dropped and its count refreshed on a preloaded proxy

- **WHEN** a post's `post_tags` proxy is loaded before a tag is added, then the tag is added and removed
- **THEN** the removed tag's published `count` is `0`
- **AND** `post.term_relationships` no longer contains the destroyed relationship
