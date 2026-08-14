# comment-submission-resilience

## Purpose

The public `save_comment` endpoint must degrade gracefully on crafted input. Because it is
unauthenticated, any request that raises an unhandled exception is a 500 an attacker can trigger at
will; malformed submissions must produce a graceful error, not a crash.

## ADDED Requirements

### Requirement: Crafted comment submissions do not 500

`save_comment` SHALL tolerate a `post_id` that names no post and a missing `post_comment` payload,
returning a graceful error response rather than raising. The post SHALL be resolved nil-safely, and
the comment payload SHALL be treated as empty when absent.

#### Scenario: A comment for a non-existent post is refused gracefully

- **WHEN** a POST to `save_comment` names a post id that does not exist
- **THEN** the endpoint responds with a "post not found" error and does not raise

#### Scenario: A missing comment payload does not crash

- **WHEN** an anonymous submission omits the `post_comment` parameter
- **THEN** the endpoint responds with a graceful error and does not raise
