## ADDED Requirements

### Requirement: Select the appropriate planning workflow
The repository agent guidance SHALL direct agents to use OpenSpec when the user requests OpenSpec or when planned work has non-trivial behavior, contract, or cross-cutting concerns. The guidance SHALL preserve direct execution for trivial, narrowly scoped, and documentation-only work.

#### Scenario: Planning a non-trivial behavior change
- **WHEN** an agent receives a request that changes behavior across multiple areas or establishes a new contract
- **THEN** the guidance directs the agent to use the appropriate OpenSpec workflow

#### Scenario: Performing a localized maintenance task
- **WHEN** an agent receives a trivial, narrowly scoped, or documentation-only task
- **THEN** the guidance permits the agent to proceed without creating an OpenSpec change

### Requirement: Follow the installed OpenSpec lifecycle
The repository agent guidance SHALL direct agents to inspect active changes before creating a new one and to use the installed OpenSpec commands and skills for exploration, artifact creation, implementation, verification, and archival.

#### Scenario: Continuing an existing change
- **WHEN** an agent identifies a relevant active OpenSpec change
- **THEN** the guidance directs the agent to continue that change instead of creating a duplicate

#### Scenario: Completing a planned change
- **WHEN** an OpenSpec change has implementation tasks
- **THEN** the guidance identifies the installed apply, verify, and archive workflows as the path to completion

### Requirement: Provide planning context without duplicating execution guidance
The OpenSpec configuration SHALL include concise Camaleon CMS planning context and artifact rules, and SHALL identify `AGENTS.md` and its linked documents as the authoritative source for detailed execution guidance.

#### Scenario: Generating a change artifact
- **WHEN** an agent creates an OpenSpec proposal, specification, design, or task artifact
- **THEN** the generated planning context identifies the Ruby on Rails engine, relevant testing conventions, and the authoritative repository guidance

#### Scenario: Updating repository execution rules
- **WHEN** detailed execution or verification guidance changes
- **THEN** the change is maintained in `AGENTS.md` or its linked documents rather than duplicated in the OpenSpec configuration
