# post-publish-timestamp Specification

## Purpose
Pin when a post's `published_at` is set. Neither the admin publish flow nor the `Post` model
required a publish date, so a post could reach the `published` status with a nil `published_at`.
That left published content undated and broke frontends that format the publish date — e.g. a theme
rendering `l(post.published_at)` raised on the nil. `CamaleonCms::Post` now stamps `published_at` at
the moment a post becomes published without a caller-supplied date, keyed to the status change so
drafts stay undated, a supplied (scheduled or backdated) date is preserved, and later edits do not
move the date.

## Requirements

### Requirement: Publishing a post without a date stamps published_at

`CamaleonCms::Post` SHALL set `published_at` to the current UTC time when a save makes the post
`published` and no `published_at` was supplied — whether the record is created already published or
an existing draft transitions to `published`. A post whose status is not `published` SHALL NOT be
stamped.

#### Scenario: A draft is published without a date

- **WHEN** an existing draft is saved with `status` changed to `published` and a blank `published_at`
- **THEN** `published_at` is set to the current time

#### Scenario: A post is created already published without a date

- **WHEN** a post is created with `status` `published` and a blank `published_at`
- **THEN** `published_at` is set to the current time

#### Scenario: A post that is not published stays undated

- **WHEN** a post is created or saved with a non-`published` status and a blank `published_at`
- **THEN** `published_at` remains nil

### Requirement: A caller-supplied published_at is preserved

When a save that publishes a post carries an explicit `published_at`, `CamaleonCms::Post` SHALL keep
that value rather than overwriting it, so a scheduled or backdated publish date survives.

#### Scenario: Publishing with a scheduled date keeps it

- **WHEN** a post is published with an explicit future `published_at`
- **THEN** `published_at` keeps the supplied value

### Requirement: Editing an already-published post does not move the date

A save that does not transition `status` into `published` SHALL NOT change an existing
`published_at`. Editing a live post preserves its original publish date, and a post already stored
`published` with a nil date is left as-is rather than stamped on an unrelated save.

#### Scenario: Editing a published post preserves published_at

- **WHEN** an already-published post is saved with an unrelated attribute change
- **THEN** `published_at` is unchanged
