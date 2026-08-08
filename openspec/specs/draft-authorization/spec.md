## Purpose

Ensure the admin draft autosave endpoint performs authorization checks and scoped lookups before mutating draft data, preventing cross-user draft overwrites and content integrity compromise.

## Requirements

### Requirement: Draft create scopes lookup to post type
The `DraftsController#create` SHALL scope its draft lookup to the requested post type, the
validated parent post, and the current user: `@post_type.posts.drafts.where(post_parent: <validated
post id>, user_id: <current user id>)`. A draft created under one post type MUST NOT be findable
or overwritable through a different post type's drafts endpoint, and another user's draft MUST NOT
be findable at all.

#### Scenario: Lookup scoped to post type
- **WHEN** User A has a draft for post 5 in post type 1 and User A sends
  `POST /admin/post_type/2/drafts` with `post_id=5`
- **THEN** the post-type-scoped lookup MUST NOT find the draft from post type 1
- **AND** a new draft MUST be created under post type 2

#### Scenario: Overwrite blocked across post types
- **WHEN** User A sends `POST /admin/post_type/2/drafts` with `post_id=5` targeting a draft in
  post type 1
- **THEN** the existing draft in post type 1 MUST NOT be modified

#### Scenario: Lookup scoped to current user
- **WHEN** a draft for post 5 exists with User B's `user_id` and User A sends
  `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** the lookup MUST NOT return User B's draft

### Requirement: Draft create requires authorization
The `DraftsController#create` SHALL authorize against the post being edited before mutating any
draft data:
- When the request carries a validated parent post: `authorize! :update, <parent post>` — for
  both overwriting the user's own existing buffer and creating the user's first buffer under that
  post
- When the request has no validated parent post (parentless new-post draft):
  `authorize! :create_post, @post_type`

The draft row's own `user_id` MUST NOT decide authorization: holding a draft row SHALL grant
nothing under a post the user cannot update, and lacking the draft row SHALL block nothing on a
post the user can update.

#### Scenario: Unauthorized user cannot overwrite another's draft
- **WHEN** User B (no `:update` permission on post 5) sends `POST /admin/post_type/1/drafts` with
  `post_id=5` while a draft for post 5 exists with another user's `user_id`
- **THEN** the request MUST raise `CanCan::AccessDenied`
- **AND** no draft MUST be created or modified

#### Scenario: Authorized user can overwrite own draft
- **WHEN** User A (who has `:update` permission on post 5) already has a draft buffer for post 5
  and sends `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** User A's draft MUST be updated with the new content

#### Scenario: Post owner autosaves while another user's buffer exists
- **WHEN** User A holds only the `edit` (own posts) permission on post type 1, owns post 5, a
  draft for post 5 exists with another user's `user_id`, and User A sends
  `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** the response MUST be the normal JSON autosave payload (no redirect)
- **AND** the resulting draft MUST be User A's own buffer, the other user's buffer unchanged

#### Scenario: Draft ownership does not grant autosave under another user's post
- **WHEN** User A holds only the `edit` (own posts) permission on post type 1, a draft for post 5
  carries User A's `user_id` but post 5 belongs to another user, and User A sends
  `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** the request MUST raise `CanCan::AccessDenied`
- **AND** User A's existing draft MUST remain unchanged

#### Scenario: edit_other role autosaves another user's post
- **WHEN** User C holds only the `edit_other` permission on post type 1, post 5 belongs to another
  user, no draft by User C exists for post 5, and User C sends `POST /admin/post_type/1/drafts`
  with `post_id=5`
- **THEN** a draft buffer owned by User C MUST be created under post 5

#### Scenario: Unauthorized user cannot create new draft
- **WHEN** User B (no `:create_post` permission for post type 1) sends
  `POST /admin/post_type/1/drafts` without a `post_id`
- **THEN** the request MUST raise `CanCan::AccessDenied`
- **AND** no new draft MUST be created

#### Scenario: Authorized user can create new draft
- **WHEN** User A (has `:create_post` permission) sends `POST /admin/post_type/1/drafts` without a
  `post_id`
- **THEN** a new parentless draft MUST be created under post type 1
- **AND** `user_id` MUST be set to User A's ID

### Requirement: Draft create preserves original user_id on overwrite
Draft buffer ownership SHALL never change hands. A new buffer SHALL stamp the current user's
`user_id`; an overwrite SHALL only ever target the current user's own buffer, leaving every other
user's buffer — and its `user_id` — untouched.

#### Scenario: Overwrite preserves ownership
- **WHEN** User B (any permissions, including full update rights on post 5) sends
  `POST /admin/post_type/1/drafts` with `post_id=5` while a draft for post 5 exists with User A's
  `user_id`
- **THEN** User A's draft MUST retain User A's `user_id` and its content

#### Scenario: New draft sets owner
- **WHEN** User A creates a new draft via `POST /admin/post_type/1/drafts`
- **THEN** the draft's `user_id` MUST be User A's ID

### Requirement: Draft update scopes lookup and requires authorization
The `DraftsController#update` SHALL scope its draft finder to the requested post type AND the
current user's drafts, and SHALL call `authorize! :update` on the draft's parent post (the draft
itself when parentless) before saving changes. A draft outside that scope MUST be treated as not
found: the request SHALL respond exactly like a request for a nonexistent draft id (the
endpoint's standard missing-record response), never as an authorization denial — revealing
neither the draft's existence nor its owner — and the draft MUST NOT be mutated.

#### Scenario: Update scoped to post type
- **WHEN** User A sends `PATCH /admin/post_type/1/drafts/42` and draft 42 is in post type 2
- **THEN** the request MUST receive the endpoint's standard missing-record response
- **AND** draft 42 MUST remain unchanged

#### Scenario: Update cannot reach another user's draft
- **WHEN** User A sends `PATCH /admin/post_type/1/drafts/42` and draft 42 carries User B's
  `user_id`
- **THEN** the request MUST receive the endpoint's standard missing-record response,
  indistinguishable from a nonexistent draft id
- **AND** draft 42 MUST remain unchanged

#### Scenario: Update unauthorized user blocked
- **WHEN** User A owns draft 42 whose parent post 5 User A can no longer update
- **THEN** `PATCH /admin/post_type/1/drafts/42` MUST raise `CanCan::AccessDenied`

#### Scenario: Update authorized user succeeds
- **WHEN** User A owns draft 42 and can update its parent post, and sends
  `PATCH /admin/post_type/1/drafts/42`
- **THEN** the draft MUST be updated with the new content
- **AND** `user_id` MUST remain User A's ID

### Requirement: post_parent validated against a real post
`post_parent` SHALL be create-only and never client-writable. On create,
`set_post_data_params` SHALL assign it unconditionally: to `params[:post_id]` when that parameter
references a post existing within the current site, and to nil otherwise — a client-supplied
`post[post_parent]` attribute MUST never survive. On update, `post_parent` SHALL NOT be modified:
neither `params[:post_id]` nor any request attribute re-parents or detaches an existing draft.

#### Scenario: post_parent set for valid post
- **WHEN** a create request carries `params[:post_id]` referencing an existing post
- **THEN** the draft's `post_parent` MUST be set to that post's ID

#### Scenario: post_parent nil for invalid post
- **WHEN** a create request carries `params[:post_id]` referencing a non-existent post
- **THEN** the draft's `post_parent` MUST be nil

#### Scenario: post_parent nil when post_id absent
- **WHEN** a create request carries no `params[:post_id]`
- **THEN** the draft's `post_parent` MUST be nil

#### Scenario: Client-supplied post[post_parent] is discarded
- **WHEN** a create request's `params[:post_id]` is absent or references a non-existent post, and
  the request body carries `post[post_parent]` naming an existing post
- **THEN** the resulting draft's `post_parent` MUST be nil
- **AND** the draft MUST NOT become a child of the named post

#### Scenario: Update never modifies post_parent
- **WHEN** an update request for a parented draft omits `params[:post_id]` (or carries any other
  value)
- **THEN** the draft's `post_parent` MUST remain unchanged

### Requirement: Per-user draft buffers
Autosave draft buffers SHALL be private to the user who created them. No request SHALL read,
overwrite, re-parent, or detach another user's draft buffer, regardless of the requester's
permissions on the parent post. Editing surfaces that link to a draft SHALL link to the current
user's own buffer only.

#### Scenario: Autosave never touches another user's buffer
- **WHEN** a draft buffer for post 5 exists with User B's `user_id` and User A (authorized to
  update post 5) sends `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** a separate draft owned by User A MUST be created (or User A's own existing buffer
  updated)
- **AND** User B's buffer MUST remain unchanged

#### Scenario: Own buffer is reused across autosaves
- **WHEN** User A already has a draft buffer for post 5 and sends another
  `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** User A's existing buffer MUST be updated in place
- **AND** no additional draft MUST be created

#### Scenario: Edit form links to the current user's own buffer
- **WHEN** drafts for post 5 exist for both User A and User B, and User A opens post 5's edit
  form
- **THEN** the "view draft" link MUST target User A's draft only

