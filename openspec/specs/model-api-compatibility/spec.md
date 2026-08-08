# model-api-compatibility Specification

## Purpose
Pin the legacy model-API surfaces external plugins and host apps were written against — media
lookup by key, category unassignment, and default navigation enumeration order — so style sweeps
and refactors cannot silently remove them again.
## Requirements
### Requirement: Media lookup by key keeps its legacy name

`CamaleonCms::Media.find_by_key` SHALL remain available as an alias of `by_key`, returning the
same relation for the same key (including through association scopes such as a site's media).
It MUST NOT fall through to Rails' dynamic finder (the media table has no `key` column, so the
fallthrough is a `NoMethodError`).

#### Scenario: Legacy and current name return the same relation

- **WHEN** code calls `site.public_media.find_by_key('/folder/file.png')`
- **THEN** the call returns the same records as `by_key` for that key
- **AND** no error is raised

### Requirement: Posts can be unassigned from categories

`unassign_category(categories_id)` SHALL remove the post's relationships to the given category
id(s) — accepting a single id or an array — and SHALL refresh the affected categories' post
counters, mirroring `assign_category`'s counter maintenance.

#### Scenario: Unassigning one of two categories

- **WHEN** a post assigned to categories A and B calls `unassign_category(A.id)`
- **THEN** the post remains assigned only to category B
- **AND** category A's post counter reflects the removal

### Requirement: Navigation menus enumerate in creation order by default

`NavMenu` and `NavMenuItem` relations SHALL carry a default ascending-id order, so external
iteration over menus and items is deterministic (2.9.2 parity). The admin and frontend render
paths SHALL keep ordering by the drag-configured `term_order` (they `reorder`, which overrides
the default).

#### Scenario: Default relations are id-ordered

- **WHEN** code enumerates `NavMenu` or `NavMenuItem` records without an explicit order
- **THEN** the generated query orders by ascending id

#### Scenario: Render paths keep term_order

- **WHEN** the admin menu builder or the frontend menu helper renders menu items
- **THEN** items appear in `term_order`, unaffected by the default scope

