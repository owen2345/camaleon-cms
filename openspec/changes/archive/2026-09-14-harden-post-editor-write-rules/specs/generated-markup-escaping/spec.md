## MODIFIED Requirements

### Requirement: The post status column MUST NOT be trusted as canonical by rendering code

A submitted `post[status]` is now held to the editor's set, but `posts.status` is still written without model validation by three writers — `PostsController#trash` and `#restore` via `update_column`, and `DraftsController` via `save(validate: false)` — and a non-canonical value may already be stored from before the request rule existed. Rendering code SHALL therefore treat the column as untrusted input regardless of any validation applied at the model or controller layer.

#### Scenario: A non-canonical status stored in the column still renders inert

- **WHEN** a post's `status` column holds a script payload (planted before the request rule through the old `options[:status_default]` restore path, now closed, or by any non-validating writer)
- **AND** an administrator opens the post list with `s=all`
- **THEN** the response contains no `<script>` element inside `#posts-table-list`
- **AND** the payload is present as escaped text in the row's status label
