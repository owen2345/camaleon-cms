# Record the member check against Camaleon master

## Why

Each enrolled ecosystem member now runs its own suite against the `master` branch of camaleon_cms,
on its own pull requests and pushes. The member repositories and `docs/ai/ecosystem.md` describe
that check. The `ecosystem-cross-testing` spec has requirements only for the runs that camaleon_cms
starts, so no requirement keeps the member check as it is.

## What Changes

- Four new requirements say what the member check does. They cover its events, the skip of the
  suite, its advisory status with forks and caches, and the names of its checks.
- The requirement on the documents also covers the member check and the README of each member.
- The Purpose of the spec names both directions of the tests.
- No code changes. The workflows are in the member repositories, and they are merged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ecosystem-cross-testing`: four added requirements for the member check, and one modified
  requirement on the documents.

## Impact

- No change for a host app, a plugin or a theme.
- A later change of a member's `camaleon_master.yml` has a requirement to keep.
