# ecosystem-cross-testing Specification

## Purpose
Verify core changes against the ecosystem members that carry their own test suite, continuously and
on the pull request that makes the change: core CI runs each enrolled member's suite against the core
commit under test and reports the outcome where the change is reviewed. This spec fixes what core CI
guarantees about those runs and the contract a member repository implements to be enrolled. The
runtime surface the members bind to is pinned separately, in `ecosystem-plugin-bindings`.

Each enrolled member also runs its suite against Camaleon `master`, on its own pull requests and
pushes. That check tests a change of the member against the code of the next Camaleon release. This
spec also fixes what that check guarantees.

## Requirements

### Requirement: Core CI runs each enrolled member's suite against the commit under test
On every pull request to core and on every push to core's default branch, core CI SHALL run the test
suite of each enrolled ecosystem member with `camaleon_cms` taken from the core commit under test,
not from a released gem. The core commit a member runs against SHALL be the same commit core's own
suite tests in that pipeline. The enrolled members are `cama_contact_form`, `camaleon-cms-seo`,
`camaleon_editor`, `camaleon-post-clone` and `florsan`.

#### Scenario: A pull request changes core
- **WHEN** a pull request is opened or updated against core
- **THEN** each enrolled member's suite SHALL run with `camaleon_cms` loaded from that pull request's
  commit under test

#### Scenario: A change lands on the default branch
- **WHEN** a commit is pushed to core's default branch
- **THEN** each enrolled member's suite SHALL run against that commit

#### Scenario: A core change breaks a member
- **WHEN** a pull request changes core behavior that an enrolled member's suite exercises, and the
  member's suite fails against it
- **THEN** that member's run SHALL fail on that pull request, before the change is merged or released

### Requirement: Member results are reported on the triggering core pipeline
Each enrolled member's result SHALL appear as its own check on the core pull request or commit that
triggered it, identified by the member's name, with the member's test output readable from that check.
One member's failure SHALL NOT cancel, skip or hide another member's run.

#### Scenario: Results appear next to core's own checks
- **WHEN** the member runs finish for a core pull request
- **THEN** the pull request's check list SHALL show one entry per enrolled member, each passing or
  failing independently, alongside core's own test and audit checks

#### Scenario: One member fails
- **WHEN** one enrolled member's suite fails and the others pass
- **THEN** the failing member's check SHALL be red with its failure output, and every other member's
  check SHALL still run to completion and report its own result

### Requirement: Member checks are advisory
Member checks SHALL inform review without gating it: they SHALL NOT be a precondition of merging a
core pull request, and the Release workflow SHALL NOT require them. A core change that knowingly
breaks a member remains subject to the `ecosystem-plugin-bindings` requirement that the affected
consumer and its disposition are recorded.

#### Scenario: An intentional break is merged
- **WHEN** a core pull request deliberately changes a contract an enrolled member depends on, and that
  member's check is red
- **THEN** the pull request SHALL still be mergeable, with the break recorded against the member as
  `ecosystem-plugin-bindings` requires

#### Scenario: A release is cut while a member check is red
- **WHEN** the Release workflow verifies CI for the release commit
- **THEN** it SHALL consider only core's own test and audit workflows, as before this capability

### Requirement: Cross-testing uses no credentials
Cross-testing SHALL work without any token, secret or deploy key in core or in a member, so that it
runs identically for pull requests from forks, which receive no secrets. Consequently only publicly
readable repositories SHALL be enrolled.

#### Scenario: A pull request comes from a fork
- **WHEN** a contributor without write access opens a core pull request from a fork
- **THEN** every enrolled member's suite SHALL run against it and report, exactly as for a pull
  request from a branch of the core repository

#### Scenario: A private repository is proposed for enrollment
- **WHEN** a private member, such as `camaleon_website`, is considered for enrollment
- **THEN** it SHALL NOT be enrolled under this capability, because reaching it requires a stored
  credential

### Requirement: An enrolled member exposes a callable core-compatibility workflow
An enrolled member SHALL expose, on its default branch, a workflow that another repository's pipeline
can call, accepting these inputs: `camaleon_cms_repository` (the `owner/name` of the core repository
to test against), `camaleon_cms_ref` (the commit, branch or tag of core to test against) and
`member_ref` (the member's own ref to test, defaulting to its default branch).

#### Scenario: Core calls the member's workflow
- **WHEN** core's pipeline calls a member's workflow with core's repository and the commit under test
- **THEN** the member's suite SHALL run from the member's default branch with `camaleon_cms` loaded
  from that commit

### Requirement: The callable workflow tests the member's own code against the given core
The workflow SHALL run the member's own code at `member_ref`, never the calling repository's code, against core at the given repository and ref. It SHALL fail exactly when the member's suite fails or cannot be set up.

#### Scenario: A member branch is tested before it merges
- **WHEN** the workflow is called with `member_ref` set to a member branch
- **THEN** the member's code SHALL be taken from that branch

### Requirement: The callable workflow has no manual trigger
The workflow SHALL NOT be startable by hand. A manual run executes in the member's default-branch context. There, code checked out from a caller-supplied ref could write the shared Actions caches that later runs restore. A run called from a core pull request is confined to that pull request's cache scope.

#### Scenario: A maintainer wants a member checked against an arbitrary core branch
- **WHEN** a maintainer wants to know whether a member passes against a core branch
- **THEN** opening a pull request for that branch in core, draft or not, SHALL run the member's
  suite against it
- **AND** the member's workflow SHALL offer no manual trigger

### Requirement: A member's gem set changes only as far as the core under test requires
A compatibility run SHALL start from the member's committed, locked gem versions and change them only
where sourcing `camaleon_cms` from the commit under test requires it, so that a failure points at core
rather than at unrelated dependency drift. The member's committed lockfile SHALL NOT be modified in
the member's repository by compatibility runs.

#### Scenario: Core's dependencies are unchanged
- **WHEN** the core commit under test declares the same dependencies as the release the member has
  locked
- **THEN** every gem other than `camaleon_cms` SHALL resolve to the version in the member's lockfile

#### Scenario: Core adds or tightens a dependency
- **WHEN** the core commit under test adds a runtime dependency or narrows a constraint
- **THEN** the run SHALL resolve the gems needed to satisfy it and SHALL leave the rest at the
  member's locked versions

### Requirement: CAMALEON_CMS_PATH switches a member to a local core checkout
An enrolled member's Gemfile SHALL source `camaleon_cms` from the directory named by the
`CAMALEON_CMS_PATH` environment variable when that variable is set, and SHALL behave exactly as before
when it is unset or empty: the released gem, the member's version floor, and a committed lockfile that
stays valid. The same switch SHALL serve local reproduction of a compatibility failure.

#### Scenario: The variable is unset
- **WHEN** a developer or the member's own CI installs the member's bundle without
  `CAMALEON_CMS_PATH`
- **THEN** `camaleon_cms` SHALL resolve from the gem source at the member's declared floor, and the
  committed lockfile SHALL be accepted unchanged

#### Scenario: The variable points at a core checkout
- **WHEN** `CAMALEON_CMS_PATH` names a directory holding a core checkout and the bundle is re-resolved
- **THEN** the member SHALL load `camaleon_cms` from that directory

### Requirement: Core migrations newer than a member's schema are applied before its suite runs
A compatibility run SHALL bring the member's test database up to the schema of the core commit under
test, applying any core migration the member's checked-in schema does not yet include, so that a core
pull request adding a migration is tested against the schema it defines rather than failing every
member on a stale one.

#### Scenario: A core pull request adds a migration
- **WHEN** the core commit under test contains a migration newer than the member's checked-in schema
- **THEN** the member's suite SHALL run against a test database that includes that migration

#### Scenario: No new core migration
- **WHEN** the member's checked-in schema already covers every core migration
- **THEN** the test database SHALL equal the member's checked-in schema

### Requirement: Enrollment is documented with the ecosystem inventory
`docs/ai/ecosystem.md` SHALL list the enrolled members and state what a repository must provide to be
enrolled. `docs/ai/testing.md` SHALL state how to reproduce a member failure locally against a
core working tree. `docs/ai/ecosystem.md` SHALL also describe the check that a member runs against
Camaleon `master` on its own events. The README of each member SHALL say which check runs on which
event, and what code the check tests.

#### Scenario: A red member check needs reproducing
- **WHEN** a contributor sees an enrolled member's check fail on their core pull request
- **THEN** the agent and contributor docs SHALL give the commands that run that member's suite
  locally against their core checkout

#### Scenario: Another member gains a suite
- **WHEN** a further ecosystem repository gains an RSpec workflow and is public
- **THEN** the documented enrollment steps SHALL be sufficient to add it without changing this spec's
  other requirements, apart from the enrolled-member list

#### Scenario: The member check is red on a pull request of the member
- **WHEN** a contributor sees the check against Camaleon `master` fail on a pull request of a member
- **THEN** the docs SHALL give the commands that run the suite of the member locally against a
  checkout of camaleon_cms `master`

### Requirement: An enrolled member runs its suite against Camaleon master on its own events

The CI of an enrolled member SHALL run the suite of the member against the `master` branch of
camaleon_cms. It SHALL do so on each event that starts the member's own tests. For a plugin, the
events are a pull request and a push to the default branch. For `florsan`, the event is each push.

#### Scenario: A pull request changes a plugin

- **WHEN** a pull request is opened or updated against an enrolled plugin
- **THEN** the suite of the plugin SHALL run with the merge commit of the pull request, and with
  `camaleon_cms` from the `master` branch

#### Scenario: A commit lands on the default branch of a plugin

- **WHEN** a commit is pushed to the default branch of an enrolled plugin
- **THEN** the suite of the plugin SHALL run with that commit, and with `camaleon_cms` from the
  `master` branch

#### Scenario: A commit is pushed to florsan

- **WHEN** a commit is pushed to a branch of `florsan`
- **THEN** the suite of `florsan` SHALL run with that commit, and with `camaleon_cms` from the
  `master` branch

### Requirement: The member check tests the commit that the member's own tests use

The run SHALL call the callable workflow of the member with `member_ref` set to the commit that the
member's own tests use in that event. The two results of a commit thus differ only in the Camaleon
code. The run SHALL read the callable workflow from that same commit.

#### Scenario: A pull request changes the callable workflow of a member

- **WHEN** a pull request of a member changes its callable workflow
- **THEN** the run of that pull request SHALL use the changed workflow

### Requirement: The member check skips the suite only when Camaleon master is the pinned release

Before the suite, the member check SHALL read the `camaleon_cms` version that the `Gemfile.lock` of
the member pins. It SHALL count the commits of camaleon_cms `master` after the tag of that version.
It SHALL skip the suite only when the count is 0, because the member's own tests then use the same
Camaleon code. When the check cannot read the version or cannot get the count, the suite SHALL run.

#### Scenario: Camaleon master has no commit after the pinned release

- **WHEN** the `Gemfile.lock` of a member pins the newest Camaleon release, and `master` has no
  commit after the tag of that release
- **THEN** the member check SHALL skip the suite

#### Scenario: Camaleon master has commits after the pinned release

- **WHEN** camaleon_cms `master` has one or more commits after the tag of the pinned version
- **THEN** the suite SHALL run against `master`

#### Scenario: A new Camaleon release that the member does not pin yet

- **WHEN** a new Camaleon release is out, `master` has no commit after it, and the `Gemfile.lock`
  of the member pins an older release
- **THEN** the suite SHALL run against `master`, until the `Gemfile.lock` pins the new release

#### Scenario: The count is not known

- **WHEN** the `Gemfile.lock` holds no readable `camaleon_cms` version, or the request for the
  count fails
- **THEN** the suite SHALL run

### Requirement: The member check is advisory

The member check SHALL be a workflow of its own in the member. It SHALL NOT be a precondition of a
merge in the member, and the Release workflow of a member SHALL NOT require it.

#### Scenario: The member check is red on a pull request of the member

- **WHEN** a pull request of a member fails against Camaleon `master`, and the member's own tests
  pass
- **THEN** the pull request SHALL still be mergeable

#### Scenario: A member release is cut while the member check is red

- **WHEN** the Release workflow of a member verifies CI for the commit of the release
- **THEN** it SHALL consider only the member's own CI workflow

### Requirement: The member check uses no stored secret

The check SHALL use no stored secret. Its only token SHALL be the token of the run, with read
permission. A pull request from a fork SHALL run the same jobs. A run inside a fork of the member
SHALL be skipped. The callable workflow takes the code of the member from the member's repository,
and a commit of the fork is not there.

#### Scenario: A pull request comes from a fork of the member

- **WHEN** a contributor without write access opens a pull request from a fork of a plugin
- **THEN** the member check SHALL run the same jobs as for a branch of the plugin repository
- **AND** the run SHALL be able to write only the caches of that pull request

#### Scenario: The workflow runs inside a fork

- **WHEN** an event starts the workflow in a fork of the member
- **THEN** the jobs of the member check SHALL be skipped

### Requirement: The member check runs no code from a free-form ref

A run on a push to the default branch of the member writes the Actions caches of that branch. The
code of such a run SHALL be only the pushed commit and camaleon_cms `master`, never a ref that a
person supplies.

#### Scenario: A push to the default branch of the member

- **WHEN** a commit is pushed to the default branch of a member
- **THEN** the run SHALL use only the pushed commit and camaleon_cms `master`, and no ref that a person supplies

### Requirement: The checks of a member name the Camaleon code that they test

The name of the RSpec check of the member's own CI SHALL show the `camaleon_cms` version that the
`Gemfile.lock` of the member pins. The workflow of the member check SHALL have the name
`Camaleon master`. Its first job SHALL have the name `Is master ahead of the release?`, and its
suite SHALL show as `Suite / RSpec`.

#### Scenario: A reader looks at the checks of a plugin pull request

- **WHEN** the checks of a plugin pull request finish, and the `Gemfile.lock` pins `camaleon_cms`
  2.9.4
- **THEN** the list SHALL show `CI / RSpec (camaleon_cms 2.9.4)`,
  `Camaleon master / Is master ahead of the release?` and `Camaleon master / Suite / RSpec`

#### Scenario: The suite against Camaleon master is skipped

- **WHEN** the first job finds no commit after the pinned release
- **THEN** the list SHALL show `Camaleon master / Is master ahead of the release?` as passed, and
  the suite as skipped
