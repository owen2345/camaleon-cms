# Tasks: reject-dangerous-post-tag-names

Spec-only change: the implementation already ships on `feature/jquery-3-upgrade`. The work is
verifying the written requirement against the shipped behavior, then archiving.

## 1. Verify the delta against the shipped implementation

- [x] 1.1 Confirm the save-time validation scans submitted tag names with the shared
      UnsafeMarkup detector under the content allowlist and trust gate, adds a validation error,
      and never transforms names (verify: read the Post validation; its specs pass).
- [x] 1.2 Confirm plain and multi-word tag names still save, and trusted/opted-out authors are
      not gated (verify: existing specs for the validation and the multi-word tag feature spec
      pass).

## 2. Archive

- [x] 2.1 `openspec archive reject-dangerous-post-tag-names` on the branch; commit the synced
      delta into `openspec/specs/post-content-sanitization/spec.md` plus the archived change as
      part of PR #1274 (verify: `openspec validate` clean).
