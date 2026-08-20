## Context

Camaleon CMS already provides OpenSpec skills and prompt commands, while `AGENTS.md` defines the repository's execution rules and links to detailed engineering guidance. Neither document currently establishes the boundary between direct work and an OpenSpec-managed change, and the OpenSpec configuration supplies no project context when artifacts are generated.

This is a documentation and planning-configuration change. It must retain `AGENTS.md` as the authoritative source for execution rules and avoid changing application behavior.

## Goals / Non-Goals

**Goals:**

- Tell agents when to use OpenSpec and how to progress a selected change.
- Keep direct execution appropriate for trivial, narrowly scoped, and documentation-only work.
- Provide concise, durable Camaleon CMS context to OpenSpec artifact generation.
- Keep project-specific execution and verification rules centralized in `AGENTS.md` and its linked documents.

**Non-Goals:**

- Require OpenSpec for every task.
- Duplicate all repository guidance in `openspec/config.yaml`.
- Change the OpenSpec CLI, its installed skills, application code, dependencies, or runtime behavior.

## Decisions

### Establish OpenSpec selection guidance in `AGENTS.md`

Add a compact workflow section that directs agents to use OpenSpec when the user requests it or when a change has non-trivial behavior, contract, or cross-cutting planning needs. The section will point to the existing command and skill workflow, including checking active changes before creating a new one.

Direct execution remains the default for simple, localized maintenance and documentation work. This preserves the repository's existing surgical-change guidance without turning planning into a mandatory gate.

**Alternative considered:** Require an OpenSpec change for every modification. This would create unnecessary artifact overhead for work that does not benefit from recorded design decisions.

### Put planner-specific context in `openspec/config.yaml`

Add a concise project context describing the Ruby/Rails engine, testing location, and the relationship to `AGENTS.md`. Add focused artifact rules that keep proposals, specs, designs, and tasks aligned with repository verification and scope conventions.

The configuration will refer to `AGENTS.md` and its linked documents instead of restating their complete contents, avoiding drift between two sources of instruction.

**Alternative considered:** Copy `AGENTS.md` into the OpenSpec configuration. This duplicates a broad execution document in a planning-specific file and makes future maintenance error-prone.

### Preserve the installed OpenSpec command surface

Reuse the existing `.github` OpenSpec prompts and skills rather than adding parallel commands or custom wrappers. Agent guidance will describe the established lifecycle at a high level, leaving command-specific behavior to the installed skills.

**Alternative considered:** Add repository-specific wrapper commands. The current command set already covers the intended workflow and wrappers would increase maintenance without addressing the guidance gap.

## Risks / Trade-offs

- [Agents overuse OpenSpec for small fixes] → Explicitly list the work that should proceed directly.
- [Planning context becomes stale] → Keep the configuration concise and point detailed rules to their authoritative documents.
- [Guidance conflicts with installed skills] → Reference the existing lifecycle rather than duplicate command semantics.
