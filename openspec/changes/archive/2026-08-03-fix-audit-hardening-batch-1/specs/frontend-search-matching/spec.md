## ADDED Requirements

### Requirement: Search queries match case-insensitively

The frontend search action SHALL downcase the visitor's query in Ruby before interpolating it into
the SQL pattern compared against `LOWER(title)` / `LOWER(content_filtered)`, so matching is
case-insensitive regardless of the database collation's own case behavior. `params[:q]` SHALL
carry the downcased query for views and hooks, matching the 2.9.2 contract.

#### Scenario: Mixed-case query finds a lower-case title on a case-sensitive collation

- **WHEN** a published post is titled `über uns`
- **AND** a visitor searches for `ÜBER` (a form only a Unicode-aware downcase can fold)
- **THEN** the results page lists the post

### Requirement: The search hook may replace the result set, including with an empty one

When an `on_render_search` hook assigns `r[:posts]`, the action SHALL use that collection as the
result set even when it is empty; the default LIKE query SHALL run only when the hook leaves
`r[:posts]` as `nil`.

#### Scenario: A hook-supplied empty result set is respected

- **WHEN** an `on_render_search` hook sets `r[:posts]` to an empty collection
- **THEN** the page renders "no results" and the default LIKE query is not used
