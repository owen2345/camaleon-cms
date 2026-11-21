## ADDED Requirements

### Requirement: An enrolled member runs its suite against Camaleon master on its own events

The CI of an enrolled member SHALL run the suite of the member against the `master` branch of
camaleon_cms. It SHALL do so on each event that starts the member's own tests. For a plugin, the
events are a pull request and a push to the default branch. For `florsan`, the event is each push.

The run SHALL call the callable workflow of the member with `member_ref` set to the commit that the
member's own tests use in that event. The two results of a commit thus differ only in the Camaleon
code. The run SHALL read the callable workflow from that same commit.

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

### Requirement: The member check is advisory and runs no code from a free-form ref

The member check SHALL be a workflow of its own in the member. It SHALL NOT be a precondition of a
merge in the member, and the Release workflow of a member SHALL NOT require it.

The check SHALL use no stored secret. Its only token SHALL be the token of the run, with read
permission. A pull request from a fork SHALL run the same jobs. A run inside a fork of the member
SHALL be skipped. The callable workflow takes the code of the member from the member's repository,
and a commit of the fork is not there.

A run on a push to the default branch of the member writes the Actions caches of that branch. The
code of such a run SHALL be only the pushed commit and camaleon_cms `master`, never a ref that a
person supplies.

#### Scenario: The member check is red on a pull request of the member

- **WHEN** a pull request of a member fails against Camaleon `master`, and the member's own tests
  pass
- **THEN** the pull request SHALL still be mergeable

#### Scenario: A member release is cut while the member check is red

- **WHEN** the Release workflow of a member verifies CI for the commit of the release
- **THEN** it SHALL consider only the member's own CI workflow

#### Scenario: A pull request comes from a fork of the member

- **WHEN** a contributor without write access opens a pull request from a fork of a plugin
- **THEN** the member check SHALL run the same jobs as for a branch of the plugin repository
- **AND** the run SHALL be able to write only the caches of that pull request

#### Scenario: The workflow runs inside a fork

- **WHEN** an event starts the workflow in a fork of the member
- **THEN** the jobs of the member check SHALL be skipped

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

## MODIFIED Requirements

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
