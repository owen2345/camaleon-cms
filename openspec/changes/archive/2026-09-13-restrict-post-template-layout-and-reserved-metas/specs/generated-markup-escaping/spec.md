## MODIFIED Requirements

### Requirement: The post status column MUST NOT be trusted as canonical by rendering code

`posts.status` is written without model validation — `PostsController#trash` via `update_column`, and `DraftsController` via `save(validate: false)` — and a non-canonical value may already be stored from before request validation was added. Rendering code SHALL therefore treat the column as untrusted input regardless of any validation applied at the model or controller layer.

**Change**: The `options[:status_default] -> trash -> restore` write path this scenario used is closed by the `post-editor-write-integrity` capability — the save refuses a submitted `status_default`, and `restore` writes only a canonical status the acting user may set. The requirement (rendering treats the column as untrusted) is unchanged; the scenario now plants the non-canonical status directly in the column, as a legacy or non-validating writer would.

#### Scenario: A status poisoned through the restore path still renders inert

- **WHEN** a post's `status` column holds a script payload (planted before this change through the old `options[:status_default]` restore path, now closed, or by any non-validating writer)
- **AND** an administrator opens the post list with `s=all`
- **THEN** the response contains no `<script>` element inside `#posts-table-list`
- **AND** the payload is present as escaped text in the row's status label
