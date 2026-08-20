## ADDED Requirements

### Requirement: Draft create scopes lookup to post type
The `DraftsController#create` SHALL scope its draft lookup to `@post_type.posts.drafts` instead of `CamaleonCms::Post.drafts`. A draft created under one post type MUST NOT be findable or overwritable by a request to a different post type's drafts endpoint.

#### Scenario: Lookup scoped to post type
- **WHEN** User A has a draft for post 5 in post type 1 and User B sends `POST /admin/post_type/2/drafts` with `post_id=5`
- **THEN** the lookup `@post_type.posts.drafts.where(post_parent: 5)` MUST NOT find User A's draft (which is in post type 1)
- **AND** a new draft MUST be created under post type 2

#### Scenario: Overwrite blocked across post types
- **WHEN** User B sends `POST /admin/post_type/2/drafts` with `post_id=5` targeting a draft in post type 1
- **THEN** the existing draft in post type 1 MUST NOT be modified

### Requirement: Draft create requires authorization
The `DraftsController#create` SHALL call `authorize!` before mutating any draft data:
- Before overwriting an existing draft: `authorize! :update, @post_draft`
- Before creating a new draft: `authorize! :create_post, @post_type`

#### Scenario: Unauthorized user cannot overwrite another's draft
- **WHEN** User B (no `:update` permission on User A's draft) sends `POST /admin/post_type/1/drafts` with `post_id=5` and a draft exists for post 5 owned by User A
- **THEN** the request MUST raise `CanCan::AccessDenied`
- **AND** the draft MUST remain unchanged

#### Scenario: Authorized user can overwrite own draft
- **WHEN** User A (who has `:update` permission and owns the draft) sends `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** the draft MUST be updated with the new content

#### Scenario: Unauthorized user cannot create new draft
- **WHEN** User B (no `:create_post` permission for post type 1) sends `POST /admin/post_type/1/drafts`
- **THEN** the request MUST raise `CanCan::AccessDenied`
- **AND** no new draft MUST be created

#### Scenario: Authorized user can create new draft
- **WHEN** User A (has `:create_post` permission) sends `POST /admin/post_type/1/drafts`
- **THEN** a new draft MUST be created under post type 1
- **AND** `user_id` MUST be set to User A's ID

### Requirement: Draft create preserves original user_id on overwrite
When `DraftsController#create` overwrites an existing draft, the draft's `user_id` SHALL NOT be changed to the current user. Only genuinely new drafts SHALL have `user_id` set to the current user.

#### Scenario: Overwrite preserves ownership
- **WHEN** User B (with `edit_other` permission) overwrites User A's draft via `POST /admin/post_type/1/drafts` with `post_id=5`
- **THEN** the draft's `user_id` MUST remain as User A's ID

#### Scenario: New draft sets owner
- **WHEN** User A creates a new draft via `POST /admin/post_type/1/drafts`
- **THEN** the draft's `user_id` MUST be User A's ID

### Requirement: Draft update scopes lookup and requires authorization
The `DraftsController#update` SHALL scope its draft finder to `@post_type.posts.drafts` and SHALL call `authorize! :update, @post_draft` before saving changes.

#### Scenario: Update scoped to post type
- **WHEN** User B sends `PATCH /admin/post_type/1/drafts/42` and draft 42 is in post type 2
- **THEN** the lookup `@post_type.posts.drafts.find(42)` MUST raise `ActiveRecord::RecordNotFound`

#### Scenario: Update unauthorized user blocked
- **WHEN** User B (no `:update` permission) sends `PATCH /admin/post_type/1/drafts/42` and draft 42 exists in post type 1 owned by User A
- **THEN** the request MUST raise `CanCan::AccessDenied`

#### Scenario: Update authorized user succeeds
- **WHEN** User A (owns draft 42) sends `PATCH /admin/post_type/1/drafts/42`
- **THEN** the draft MUST be updated with the new content
- **AND** `user_id` MUST remain as User A's ID (not overwritten)

### Requirement: post_parent validated against a real post
The `set_post_data_params` SHALL only set `post_parent` from `params[:post_id]` when the referenced post exists within the current site. If the post does not exist, `post_parent` SHALL be nil.

#### Scenario: post_parent set for valid post
- **WHEN** `params[:post_id]` is present and references an existing post
- **THEN** `post_parent` MUST be set to the post's ID

#### Scenario: post_parent nil for invalid post
- **WHEN** `params[:post_id]` references a non-existent post
- **THEN** `post_parent` MUST be nil

#### Scenario: post_parent nil when post_id absent
- **WHEN** `params[:post_id]` is not present
- **THEN** `post_parent` MUST be nil
