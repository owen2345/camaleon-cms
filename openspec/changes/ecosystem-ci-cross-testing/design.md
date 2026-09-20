## Context

Motivation and scope: see `proposal.md`. Facts the approach rests on, checked 2026-09-20:

- Core CI is `current_support.yml`, `experimental_support.yml` and `audit.yml` on `pull_request` and
  push to `master`, plus the manual `release.yml`, which requires successful `current_support.yml` and
  `audit.yml` runs for the release commit and nothing else. `master` has no branch protection.
- The three plugins (`owen2345/*`, default branch `master`) test against a `spec/dummy` app on
  sqlite with a checked-in `schema.rb`; `camaleon_editor` and `cama_contact_form` also need
  chromedriver. `florsan` (`texpert/florsan`, default branch `main`) is a Rails app on Postgres 16.
  All four read Ruby from `.tool-versions` (3.4.10), pin `rubygems: 4.0.19`, commit `Gemfile.lock`,
  and declare `gem 'camaleon_cms', '>= 2.9.4'`, locked to the released 2.9.4.
- The maintainer has push but not admin rights on every `owen2345/*` repository, core included, so
  cannot create Actions secrets there. Pull requests from forks receive no secrets in any case.
- Core's gemspec depends on `cama_contact_form` and `cama_meta_tag`; the plugins already resolve that
  cycle today through their `gemspec` line, and sourcing core from a path does not change it.

## Goals / Non-Goals

**Goals:**

- Results land on the core PR natively, as checks with logs, with no polling and no status API.
- One mechanism for all four members, plugin or host app.
- A member repository stays inert until called: its own CI, lockfile and releases are untouched.
- Every piece is provable before anything merges.

**Non-Goals:**

- Anything needing a credential (`camaleon_website`; see `proposal.md`).
- Reusing the members' existing `ci.yml` jobs. Their install step is lockfile-frozen, which is exactly
  what a compatibility run cannot be (Decision 4).

## Decisions

### 1. Reusable workflows (`workflow_call`), not dispatch-and-report

Core calls a workflow that lives in the member: `uses: <owner>/<member>/.github/workflows/core_compat.yml@<default branch>`.
A called workflow runs inside the caller's run, so its jobs are checks on the core PR, its logs are
core's logs, and it needs no token in either direction.

Alternative, `repository_dispatch` into the member plus a commit status posted back (or a
trigger-and-wait action): needs an `actions:write` token stored in core and a `statuses:write` token
stored in each member, which the maintainer cannot create on `owen2345/*`, and none of it runs on fork
PRs. `pull_request_target` would hand a write token to fork code. Rejected.

Alternative, core's workflow checks out each member and runs its suite with steps written in core:
also token-free, but core would own and duplicate each member's setup (Postgres service, chromedriver,
DB preparation) and drift from it. With the workflow in the member, the member's maintainers change
setup and compatibility run together.

### 2. One caller job per member, pinned to the member's default branch

`uses:` accepts neither an expression nor a matrix value, so `ecosystem.yml` has four literal jobs,
each named after its member so the check reads `cama_contact_form / RSpec`. Independent jobs with no
`needs:` give the required isolation: one red member does not stop the others.

The ref after `@` is the member's default branch (`master`, `main` for `florsan`), not a SHA: the
point is to test core against the member as it currently is, and a SHA pin would need a bump PR in
core for every member merge. Core's other workflows pin third-party actions by SHA; these four
repositories are maintained by the same people, and the called workflow gets a read-only token and no
secrets (Decision 8), so a mutable ref costs nothing there.

### 3. Core passes `github.repository` and `github.sha`

On `pull_request`, `github.sha` is the PR's merge commit, which is what `actions/checkout` gives
core's own suite, so members test the same tree. It lives in the base repository (`refs/pull/N/merge`),
so `github.repository` is the right owner for fork PRs too and no fork URL is needed. On push it is
the pushed commit. `actions/checkout` fetches a bare SHA directly.

Alternative, `github.event.pull_request.head.sha` from `head.repo.full_name`: tests the branch tip
rather than the merge result, diverging from core's own checks. Rejected.

### 4. Member side: path-sourced core, conservative re-lock, manual bundle cache

Inside a called workflow every `github.*` value is the caller's, and a bare `actions/checkout` would
check out core. So the member workflow names itself: it checks out `<owner>/<member>` at
`inputs.member_ref` into `member/` and core at `inputs.camaleon_cms_repository`/`camaleon_cms_ref`
into `camaleon_cms/`, side by side, with `defaults.run.working-directory: member`. Nesting core under
the member's tree was considered and dropped: side by side mirrors the maintainers' local layout and
keeps the member's tree free of a second Rails root.

The Gemfile switch is `gem 'camaleon_cms', path: ENV['CAMALEON_CMS_PATH']` when the variable is
non-empty, else today's line. The workflow sets `CAMALEON_CMS_PATH: ../camaleon_cms`; Bundler resolves
`path:` relative to the Gemfile, which sidesteps `github.workspace` in job-level `env`.

Install cannot use `bundler-cache: true`. With a lockfile present `ruby/setup-ruby` sets
`deployment true` in the local Bundler config; the Gemfile no longer matches the committed lock, so
the install aborts, and local config outranks environment variables, so `BUNDLE_DEPLOYMENT=false`
does not help. Deleting the lock would re-resolve everything and let unrelated gems drift. Instead:
`setup-ruby` without the cache, `bundle lock` in place (Bundler unlocks `camaleon_cms`, whose source
changed, and keeps every other locked version that still satisfies the graph), then `actions/cache`
on `vendor/bundle` keyed on the re-resolved lock, then `bundle install`. The rewritten lock exists
only in the runner's workspace.

Alternative, a second gemfile (`gemfiles/core_head.gemfile` with `eval_gemfile`): Bundler refuses the
same gem declared twice with different sources, so the main Gemfile needs the conditional anyway, and
a second lock would start empty. Rejected.

### 5. Database: load the member's schema, then migrate

The plugins load a checked-in `spec/dummy/db/schema.rb` built from released core; `florsan` loads its
own. A core PR that adds a migration would otherwise fail every member on a missing table or column,
which is not a compatibility signal. The compatibility run does `db:test:prepare` then `db:migrate`
in the test environment: core's engine appends its migrations to the host's paths
(`auto_include_migrations`), schema load marks everything up to the schema's version as applied, and
`db:migrate` applies only what is newer. With nothing newer it is a no-op. The schema dump it triggers
touches only the runner's workspace.

Verified during apply: each plugin's dummy has core's `db/migrate` in its migration paths, and
`db:migrate` from `spec/dummy` is a clean no-op that leaves `schema.rb` untouched. `florsan` differs:
its `config/system.json` turns `auto_include_migrations` off and it keeps copies of the engines'
migrations in its own `db/migrate`, so its compatibility run first copies whatever is missing with
`railties:install:migrations` (a no-op when nothing is), then loads the schema and migrates.

A local-only trap, not present in the runner's layout: the engine decides whether the host is its
own dummy app with an unanchored match of the host path against the engine root, so a core checkout
at `…/camaleon-cms` beside a member at `…/camaleon-cms-seo` silently drops core's migrations from
that member's paths. `docs/ai/testing.md` says how to avoid it; fixing the match is a separate change.

### 6. Trigger on the member: `workflow_call` only

The first version also declared `workflow_dispatch` with the same three inputs, as a manual "run this
member against core ref X". CodeQL flagged it on `florsan` (`actions/cache-poisoning/poisonable-step`,
high), and rightly: a dispatched run executes in the member's default-branch context, the inputs are
free-form, and the natural use is pointing it at a contributor's fork, whose code then runs during
`bundle lock`, the database tasks and the suite. Any process in a job can obtain the runner's cache
credential, which `permissions:` does not limit, so that code could plant default-branch-scoped cache
entries that later runs in the member restore. No secret-bearing workflow in the members restores a
cache today, so the present damage is a corrupted CI run, but one `bundler-cache: true` in a release
workflow would turn it into a publishing compromise of a gem.

The called path has no such reach: on a core pull request the run is a `pull_request` run in core,
its cache writes are scoped to that pull request, the token is read-only and there are no secrets. So
the manual trigger is removed rather than hardened (pinning the repository does not help, since
`refs/pull/N/head` in it is still contributor code), each member's workflow header says why, and the
manual need is met by opening a draft core pull request for the branch in question.

No `pull_request` trigger on the member side either: there the inputs are empty and checkout would
need a second, conditional code path to pick the member's PR commit. Left out until wanted (proposal
non-goal).

### 7. Advisory by construction

Nothing to configure: `master` has no required checks and `release.yml` names the two workflows it
requires. `continue-on-error` is not available on a job that calls a reusable workflow, so a red
member does turn the PR's overall status red; that is the intended signal. If branch protection is
ever added, these checks stay out of the required set, and `docs/ai/ecosystem.md` says so.

### 8. Permissions, concurrency, skip-ci

`ecosystem.yml` declares `permissions: contents: read`; a called workflow can only narrow that, and
`core_compat.yml` declares the same. Checkouts use `persist-credentials: false`, as the members' CI
does. Fork code already runs in core's own suite under the same read-only, secretless token, so the
member runs add no new exposure.

`ecosystem.yml` sets a concurrency group per ref and cancels in-progress runs on `pull_request` only,
so a newer push to a PR does not leave four stale member runs going, while each commit on `master`
keeps its own run as its record. The member workflow sets none; the caller owns it.

A `[skip ci]` head commit suppresses this workflow like the others. No special case.

### 9. Rollout proves each piece before anything merges

A reusable workflow can be called at any ref, and `member_ref` exists so the member's code can come
from the same branch. So: the pilot member (`cama_contact_form`) gets its branch pushed; core's branch
calls it `@<that branch>` with `member_ref: <that branch>` and the core PR's own run is the proof.
The remaining three follow the proven template. Once the member PRs are merged, core's `uses:` lines
flip to the default branches and drop `member_ref`, and that push is the final proof. Member PRs are
inert on their own, so merging them early is safe; rollback of the whole feature is deleting
`ecosystem.yml`.

Commits, pushes and PRs in every repository wait for the maintainer's explicit approval, one PR at a
time, per the standing workflow rules.

## Risks / Trade-offs

- [A member's default branch is broken for its own reasons, and every core PR shows red] → The
  member's own CI catches that first; the check is advisory; the log shows the failure is not in code
  the core PR touched.
- [`owen2345/camaleon-cms` may restrict which actions and reusable workflows can run; the setting is
  not readable without admin] → The pilot run showed a same-owner call (`owen2345/cama_contact_form`)
  is allowed; a call across owners is still unproven until `florsan` is added. `florsan`, under another owner, is
  the likeliest to be refused; if so it is dropped from `ecosystem.yml` or the owner adjusts the policy.
- [Conservative re-lock still moves a gem when core master requires it] → That is a true statement
  about core master and what a host app will hit on upgrade. The re-resolved lock is printed in the
  job log so the moved gem is visible.
- [Members run on one Ruby with one gem set, so a break specific to another Rails or Ruby is missed] →
  Accepted; core's matrix covers core, and a member matrix would multiply CI time for little signal.
- [An intentional contract change turns a member red until the member adapts and releases] →
  Expected and useful; record the consumer and disposition as `ecosystem-plugin-bindings` requires,
  then fix the member.
- [Caches live in core's Actions cache, 10 GB shared with the matrix] → Four bundles of a few hundred
  MB; keys include the lock hash, so stale entries age out.
- [Four extra jobs per push] → Public repositories, free minutes; concurrency cancellation trims
  superseded runs.

## Migration Plan

1. Pilot: `cama_contact_form` branch (Gemfile switch + `core_compat.yml`), verified locally with
   `CAMALEON_CMS_PATH`, pushed after approval.
2. Core branch: `ecosystem.yml` calling the pilot branch; PR opened after approval; the PR's run
   proves the mechanism, including the Actions policy.
3. `camaleon-cms-seo`, `camaleon_editor`, `florsan`: same template, each verified locally, each pushed
   and added to core's `ecosystem.yml` at its branch after approval.
4. Member PRs merge. Core flips to default branches, docs and changelog land, the change is archived
   on the branch, the core PR merges.

Rollback: delete `ecosystem.yml` in core. Members need no rollback; an uncalled workflow and an unset
environment variable do nothing.

## Open Questions

- Whether `camaleon_website` later gets a push-to-`master`-only dispatch, once someone with admin
  rights on core can store the token. Does not affect this change.
