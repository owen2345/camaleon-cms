# ecosystem-cross-testing Specification

## Purpose
Verify core changes against the ecosystem members that carry their own test suite, continuously and
on the pull request that makes the change: core CI runs each enrolled member's suite against the core
commit under test and reports the outcome where the change is reviewed. This spec fixes what core CI
guarantees about those runs and the contract a member repository implements to be enrolled. The
runtime surface the members bind to is pinned separately, in `ecosystem-plugin-bindings`.

## Requirements

### Requirement: Core CI runs each enrolled member's suite against the commit under test
On every pull request to core and on every push to core's default branch, core CI SHALL run the test
suite of each enrolled ecosystem member with `camaleon_cms` taken from the core commit under test,
not from a released gem. The core commit a member runs against SHALL be the same commit core's own
suite tests in that pipeline. The enrolled members are `cama_contact_form`, `camaleon-cms-seo`,
`camaleon_editor` and `florsan`.

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
`member_ref` (the member's own ref to test, defaulting to its default branch). The workflow SHALL run the member's own code at `member_ref`, never the calling repository's
code, against core at the given repository and ref, and SHALL fail exactly when the member's suite
fails or cannot be set up. The workflow SHALL NOT be startable by hand: a manual run executes in the
member's default-branch context, where code checked out from a caller-supplied ref could write the
shared Actions caches later runs restore, whereas a run called from a core pull request is confined
to that pull request's cache scope.

#### Scenario: Core calls the member's workflow
- **WHEN** core's pipeline calls a member's workflow with core's repository and the commit under test
- **THEN** the member's suite SHALL run from the member's default branch with `camaleon_cms` loaded
  from that commit

#### Scenario: A maintainer wants a member checked against an arbitrary core branch
- **WHEN** a maintainer wants to know whether a member passes against a core branch
- **THEN** opening a pull request for that branch in core, draft or not, SHALL run the member's
  suite against it, and the member's workflow SHALL offer no manual trigger

#### Scenario: A member branch is tested before it merges
- **WHEN** the workflow is called with `member_ref` set to a member branch
- **THEN** the member's code SHALL be taken from that branch

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
enrolled, and `docs/ai/testing.md` SHALL state how to reproduce a member failure locally against a
core working tree.

#### Scenario: A red member check needs reproducing
- **WHEN** a contributor sees an enrolled member's check fail on their core pull request
- **THEN** the agent and contributor docs SHALL give the commands that run that member's suite
  locally against their core checkout

#### Scenario: Another member gains a suite
- **WHEN** a further ecosystem repository gains an RSpec workflow and is public
- **THEN** the documented enrollment steps SHALL be sufficient to add it without changing this spec's
  other requirements, apart from the enrolled-member list
