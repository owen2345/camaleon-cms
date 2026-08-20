## Purpose

Define how repository agent guidance is structured for progressive disclosure: a self-sufficient `AGENTS.md` entry point with per-task linked documents and OpenSpec as the home for durable knowledge.

## Requirements

### Requirement: AGENTS.md is a self-sufficient entry point
`AGENTS.md` SHALL contain every execution invariant that applies to all tasks (stack acknowledgement, branch naming, the `spec/dummy` subshell rule, key verification commands, the spec-coverage rule, and OpenSpec routing) so that an agent needs no mandatory secondary reading before starting work.

#### Scenario: Agent starts an arbitrary task
- **WHEN** an agent reads only `AGENTS.md` before beginning a task
- **THEN** it has every always-applicable rule inline and is not directed to read any other file as a mandatory boot step

#### Scenario: Task needs domain-specific detail
- **WHEN** a task involves testing, code conventions, workflow/PR protocol, secrets, or a pre-PR audit
- **THEN** `AGENTS.md` routes the agent to exactly one linked document for that concern via a load-per-task table

### Requirement: Entry point auto-loads without eager tree imports
The repository SHALL provide a `CLAUDE.md` whose sole content is the `@AGENTS.md` import so Claude Code sessions load the entry point automatically, and `AGENTS.md` SHALL reference its per-task documents only as plain (non-`@`) paths so they are not eagerly imported.

#### Scenario: Claude Code session starts
- **WHEN** a Claude Code session starts in the repository
- **THEN** `CLAUDE.md` imports `AGENTS.md` into context and no `docs/ai/` document is imported at session start

#### Scenario: Editing AGENTS.md references
- **WHEN** a maintainer adds or edits a document reference in `AGENTS.md`
- **THEN** the reference uses a plain backticked path, never an `@`-prefixed import

### Requirement: Linked documents load per task and exist
Every file referenced by `AGENTS.md` or its linked documents SHALL exist in the repository, and every section reference SHALL resolve to a real section in the target document.

#### Scenario: Following a document reference
- **WHEN** an agent follows any file path or section reference in `AGENTS.md`, `docs/ai/workflows.md`, `docs/ai/reference.md`, `docs/ai/testing.md`, `docs/ai/secrets.md`, or `docs/ai/criteria.md`
- **THEN** the referenced file exists and the referenced section is present in it

#### Scenario: Superseded process systems are absent
- **WHEN** an agent inspects `docs/ai/` for guidance
- **THEN** no knowledge-architecture, decision-journal, deletion-tracker, quality-gate, or mechanical-overrides documents are present, and no surviving document instructs the agent to consult them

### Requirement: Each execution rule has one authoritative statement
Each execution rule SHALL be stated normatively in exactly one document; other documents MAY reference that statement but SHALL NOT restate it as an independent rule.

#### Scenario: Locating the security-fix testing rule
- **WHEN** an agent needs the requirement that vulnerability fixes include a reproducing test
- **THEN** exactly one document states the rule normatively and any other mention points to that document

#### Scenario: Updating a duplicated rule
- **WHEN** a maintainer changes an execution rule (for example, the refactoring phase size)
- **THEN** the change requires editing only the rule's single authoritative document

### Requirement: Durable knowledge and decisions flow to OpenSpec
The agent guidance SHALL direct lasting decisions and durable domain knowledge to OpenSpec artifacts (change `design.md` records and `openspec/specs/`) rather than to parallel journal or knowledge systems under `docs/ai/`.

#### Scenario: Agent makes a lasting design decision
- **WHEN** an agent makes a decision that outlives the current task inside an OpenSpec change
- **THEN** the guidance directs it to record the decision in the change's `design.md`, not in a `docs/ai/` journal

#### Scenario: Agent discovers durable domain behavior
- **WHEN** an agent identifies behavior worth preserving as a contract
- **THEN** the guidance directs it toward OpenSpec specs rather than a `docs/ai/knowledge/` hierarchy
