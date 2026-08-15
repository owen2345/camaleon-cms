# comment-submission-resilience Specification

## Purpose
The public `save_comment` endpoint must degrade gracefully on crafted input. Because it is
unauthenticated, any request that raises an unhandled exception is a 500 an attacker can trigger at
will; malformed submissions must produce a graceful error, not a crash. The post-submit redirect
must likewise never become an open redirect (or an unsafe-redirect 500) via a crafted `Referer`.
## Requirements
### Requirement: Crafted comment submissions do not 500

`save_comment` SHALL tolerate crafted input without raising: a `post_id` that names no post, a
`post_comment` payload that is absent or not hash-shaped (a scalar or array), and a
`post_comment[parent_id]` that names no comment on the post. The post SHALL be resolved nil-safely,
the payload SHALL be treated as empty unless it is hash-shaped, and a supplied parent id that
resolves to nothing SHALL yield a graceful error rather than a crash.

#### Scenario: A comment for a non-existent post is refused gracefully

- **WHEN** a POST to `save_comment` names a post id that does not exist
- **THEN** the endpoint responds with a "post not found" error and does not raise

#### Scenario: A missing comment payload does not crash

- **WHEN** an anonymous submission omits the `post_comment` parameter
- **THEN** the endpoint responds with a graceful error and does not raise

#### Scenario: A non-hash comment payload does not crash

- **WHEN** a submission sends `post_comment` as a scalar or array rather than a hash
- **THEN** the payload is treated as empty and the endpoint does not raise

#### Scenario: A parent_id naming no comment is refused gracefully

- **WHEN** a submission sets `post_comment[parent_id]` to an id that matches no comment on the post
- **THEN** the endpoint responds with a "parent comment not found" error and does not raise

### Requirement: The post-submit redirect does not trust the Referer

After handling a non-JSON submission, `save_comment` SHALL redirect to the request `Referer` only
when it is same-host (or an explicitly allowlisted host); an off-host `Referer` SHALL be dropped in
favor of the post URL or the site root. The raw header is therefore never an open redirect, nor a
source of an unsafe-redirect 500.

#### Scenario: An off-host Referer is not honored

- **WHEN** a non-JSON submission carries a `Referer` header pointing at a different host
- **THEN** the redirect targets the post URL or the site root, not the Referer, and does not raise

#### Scenario: A same-host Referer is honored

- **WHEN** a non-JSON submission carries a same-host `Referer` header
- **THEN** the redirect targets that Referer
