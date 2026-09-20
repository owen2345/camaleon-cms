## Why

A core change is verified only against core's own suite. The plugins and host applications that bind
to the engine (`docs/ai/ecosystem.md`) have their own RSpec suites now, but they run against the
released gem, so a core PR that breaks one of them is discovered after the release, by hand. Four
members already carry a working RSpec workflow; core CI can run them against the commit under test
and show the outcome on the PR that caused it.

## What Changes

- Core gains a CI workflow that, on every pull request and every push to `master`, runs each enrolled
  ecosystem member's RSpec suite against the core commit under test. Each member shows up as its own
  check on the core PR, with its logs, next to the existing matrix.
- Enrolled members, all public: `cama_contact_form`, `camaleon-cms-seo`, `camaleon_editor` (plugins)
  and `florsan` (host application).
- Each member gains a callable "core compatibility" workflow that takes the core repository and ref
  to test against, and a `CAMALEON_CMS_PATH` switch in its Gemfile that sources `camaleon_cms` from a
  local checkout. With the variable unset a member behaves exactly as today.
- The member checks are advisory: they do not gate merging and the Release workflow does not require
  them.
- No tokens or secrets anywhere, so the checks run the same on pull requests from forks.
- `docs/ai/ecosystem.md` and `docs/ai/testing.md` document the enrolled members, how to reproduce a
  member failure locally, and how to enroll another member.

Non-goals:

- `camaleon_website`. It is private and owned by a different account than core, so core cannot call a
  workflow in it; reaching it needs a dispatch token stored as a core repository secret, which would
  not run on fork PRs and would link to logs contributors cannot open. It stays on local verification.
- Members without a suite of their own (the rest of the `README.md` plugin and theme list).
- Running members across core's Ruby and Rails matrix. Each member runs once, on its own Ruby and its
  own locked gem set.
- Testing a member's pull requests against core `master` from the member's side.

## Capabilities

### New Capabilities

- `ecosystem-cross-testing`: core CI runs enrolled ecosystem members' suites against the core commit
  under test and reports each result on the triggering pipeline; the contract a member implements to
  be enrolled (callable workflow inputs, the `CAMALEON_CMS_PATH` Gemfile switch), and the advisory,
  credential-free nature of the checks.

### Modified Capabilities

None. `ecosystem-plugin-bindings` pins the runtime surface members bind to; this change verifies that
surface continuously and changes none of its requirements.

## Impact

- **camaleon-cms**: new `.github/workflows/ecosystem.yml`; `docs/ai/ecosystem.md`,
  `docs/ai/testing.md`, `CHANGELOG.md`. No gem code, no runtime behavior, nothing shipped in the gem.
  `release.yml` and the two matrix workflows are untouched.
- **cama_contact_form, camaleon-cms-seo, camaleon_editor** (`owen2345/*`, default branch `master`)
  and **florsan** (`texpert/florsan`, default branch `main`): new
  `.github/workflows/core_compat.yml`, a `CAMALEON_CMS_PATH` branch in `Gemfile`, a changelog entry
  where the repository keeps one. Their existing CI, committed `Gemfile.lock` and released gems are
  unchanged.
- **Merge order**: a member's workflow must be on its default branch before core can reference it
  there, so the four member PRs merge before the core PR does.
- **CI cost**: four more jobs per core push, each one member suite on one Ruby. All five repositories
  are public, so the minutes are free; bundles are cached in core's Actions cache.
