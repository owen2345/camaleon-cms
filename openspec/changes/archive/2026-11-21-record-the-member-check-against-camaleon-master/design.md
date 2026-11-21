# Design

## Context

`ecosystem-ci-cross-testing` made camaleon_cms run the suite of each enrolled member against the
camaleon_cms commit under test. That run tests the default branch of the member. A change in a
member was tested only against the released gem that its `Gemfile.lock` pins.

On 2026-10-04 the maintainer asked for the other direction: the CI of each member also runs its
suite against camaleon_cms `master`. The five members got a `camaleon_master.yml` on 2026-11-20
(camaleon_editor #23, cama_contact_form #95, camaleon-cms-seo #61, camaleon-post-clone #5,
texpert/florsan #3361). `docs/ai/ecosystem.md` and `docs/ai/testing.md` describe the check
(camaleon-cms #1358). This change adds the requirements.

## Goals / Non-Goals

**Goals:**

- The spec holds the decisions of the member check, so that a later edit of a member workflow has a
  requirement to keep.

**Non-Goals:**

- A change of a workflow. The workflows are in the member repositories.
- A required check. The member check stays advisory.

## Decisions

**D1. The check is advisory, in a workflow of its own.** The maintainer decided this on 2026-11-20.
The Release workflow of a plugin requires a green run of `ci.yml` only. A job inside `ci.yml` would
block a release when Camaleon `master` breaks the plugin. The requirement thus names a workflow of
its own.

**D2. The first job compares `master` with the tag of the pinned version.** The other option was the
newest release of camaleon_cms. With that option, a new release with no later commit skips the
suite. The member then still tests against the older gem that its lock pins.

The pinned version closes that hole: the suite runs until the lock pins the new release. The tag of
a release is its version, on a `master` commit, so the count is exact.

**D3. Only a known count of 0 skips the suite.** A lock with no readable version and a failed
request both give an unknown count. A skipped suite on an unknown count hides a failure, so the
suite runs.

**D4. The run tests the commit that the member's own tests use.** On a pull request, that commit is
the merge commit. The base repository holds it, also for a pull request from a fork. The two RSpec
results of one commit thus differ only in the Camaleon code. The callable workflow is read from the
same commit, so a pull request that changes it is tested with its own version.

**D5. A run inside a fork is skipped.** The callable workflow takes the code of the member from the
repository of the member. A commit that only a fork holds is not there. A guard on the repository
name keeps the three inputs of the callable workflow as they are.

**D6. The callable workflow keeps no manual trigger.** A run on a push to the default branch writes
the caches of that branch. Its code is the pushed commit and camaleon_cms `master`. A manual run
with a free-form ref could write those caches from code that nobody reviewed.

**D7. `florsan` runs the check on each push.** Its own CI runs on pushes only, and the check
follows the events of the member's own tests.

**D8. The names of the checks say what they test.** The maintainer chose the names on 2026-11-20:
`Camaleon master / Is master ahead of the release?`, `Camaleon master / Suite / RSpec`, and the
pinned version in the name of the RSpec check of the member's own CI. The first names were
`Core compatibility` and `Core master`, and the maintainer found them ambiguous.

## Risks / Trade-offs

- A member check is red for a Camaleon change, not for the member's commit. → The checks on the
  camaleon_cms commits show which side broke, and the check blocks no merge.
- The requirement names the checks. A rename needs a change of this spec. → The names are what a
  reader sees on a pull request, so a rename is a change of behavior for that reader.
