## Purpose

Define what happens to a deleted user's content: comments are reassigned to the site's anonymous user, widgets survive, posts move to a surviving admin or are detached, and comments orphaned by the post-2.9.2 regression render safely and are repairable by rake task.

## Requirements

### Requirement: A deleted user's comments are reassigned to the site's anonymous user

When a user is destroyed, every comment they authored SHALL be reassigned to the owning site's
anonymous user (created on demand by `Site#get_anonymous_user`) — never left with a `NULL`
`user_id`. Comment rendering after the deletion SHALL keep working.

#### Scenario: Comment survives its author's deletion

- **WHEN** a user who commented on another user's post is destroyed
- **THEN** the comment still exists and its `user_id` is the site's anonymous user's id
- **AND** `the_author_name` on the decorated comment renders without error

### Requirement: A deleted user's widgets survive

Destroying a user SHALL NOT destroy the widgets they created; sidebar widgets keep rendering
after their creator's account is removed, as on 2.9.2.

#### Scenario: Widget survives its creator's deletion

- **WHEN** a user who created a sidebar widget is destroyed
- **THEN** the widget row still exists

### Requirement: A deleted user's posts go to a surviving admin, else are detached

`before_destroy` reassignment of the deleted user's posts (and the comments on them) to another
admin of the same site SHALL be attempted first; posts with no surviving admin SHALL have
`user_id` set to `NULL` rather than keeping a dangling id.

#### Scenario: Posts move to the surviving admin

- **WHEN** a site has a second admin and a post author is destroyed
- **THEN** the author's posts belong to the surviving admin

### Requirement: Comment rendering tolerates a missing author and orphans are repairable

`PostCommentDecorator#the_user`, `#the_author_name`, and `#the_author_email` SHALL NOT raise when
the comment's user is missing (rows orphaned while the regression was live).
`rake camaleon_cms:reassign_orphaned_comments` SHALL reassign comments with a missing user to the
owning site's anonymous user, and SHALL NOT modify comments whose user exists.

#### Scenario: Orphaned comment renders and is repaired

- **WHEN** a comment row's `user_id` is `NULL`
- **THEN** `the_author_name` returns blank output instead of raising
- **AND** after running `camaleon_cms:reassign_orphaned_comments` the comment's `user_id` is the
  site's anonymous user's id
