# Stop crafted save_comment requests from 500ing (Low)

## Why

`save_comment` is a public, unauthenticated endpoint. A POST naming a non-existent post id reached
`current_site.posts.find_by(id: ...).decorate` on `nil` (`NoMethodError` → 500), and the anonymous
branch indexed `params[:post_comment]` with no nil-guard (500 when the param is omitted). Either is a
crafted-input 500 an attacker can trigger at will — a robustness/DoS Low. Audit Low.

### Triage verdict: legit

Reproduced in `spec/requests/security/save_comment_robustness_spec.rb`: a POST to
`/save_comment/999999` raises `NoMethodError: undefined method 'decorate' for nil`, and an anonymous
submission without `post_comment` raises `NoMethodError: undefined method '[]' for nil`, before the
fix.

## What Changes

- `save_comment` resolves the post with `&.decorate` and, when it is nil, records a "post not found"
  error instead of crashing.
- `post_comment` defaults to an empty hash, so a missing param yields nil fields (which then fail
  validation gracefully) rather than a 500.
- The no-referer redirect fallback no longer dereferences a nil post.

## Notes for upgraders

- None. Legitimate submissions are unaffected; only crafted requests that used to 500 now return a
  graceful error.
