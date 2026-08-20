## Purpose

State the actual scope of post slug uniqueness so documentation and upgrade notes describe what
the validator enforces rather than what a changelog assumed.

## ADDED Requirements

### Requirement: Post slug uniqueness is site-wide across post types

`PostUniqValidator` SHALL reject a slug that any non-draft, non-trashed post of the **same site**
already holds — regardless of post type or parent. Drafts and draft children SHALL be exempt
(both as the record being validated and as blocking records). Multilingual slugs SHALL collide
per language through their translation markers.

#### Scenario: Cross-post-type duplicate is refused

- **WHEN** a published post of post type A holds slug `s` and a post of post type B in the same
  site validates with slug `s`
- **THEN** validation fails with the requires-different-slug error

#### Scenario: Same-post-type duplicate is refused

- **WHEN** a published post holds slug `s` and another post of the same post type validates with
  slug `s`
- **THEN** validation fails with the requires-different-slug error

#### Scenario: Drafts do not participate

- **WHEN** the record being validated is a draft
- **THEN** validation is skipped entirely
