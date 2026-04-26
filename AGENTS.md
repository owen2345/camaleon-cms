# Camaleon CMS: Agent Entry Point

## 0. MANDATORY BOOT SEQUENCE
Before performing ANY action or proposing ANY code, you MUST:
1. **Load Context:** Read the `must-read` files listed in [Progressive Guidance](#progressive-guidance) that are relevant to the current phase (e.g., if starting a task, load `workflows.md`; if writing code, load `testing.md`).
2. **State Your Stack:** Explicitly acknowledge you are working with Ruby `3.4.9` and Rails `8.1.3`.
3  **Initialize Workflow:** State which branch you are on and which PR flow from `workflows.md` you are following.

**DO NOT proceed to "Think Before Coding" until you have initialized your context via these files.**

## Agent Behaviour

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

#### Security Triage Exception

If the user provides a vulnerability report:
- **HALT** all coding.
- You must **verify legitimacy** first (see `docs/ai/workflows.md#vulnerability-triage`).
- Do not create a branch or fix until you have demonstrated the vulnerability locally.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
When providing "Further Considerations," wait for explicit confirmation before proceeding with any next steps or implementations.

## Progressive Guidance
> **Rule:** You must `read` any file marked `must-read` before executing a related task.

### Core Execution (Load these first)
- [Workflow and branch/PR flow](./docs/ai/workflows.md) `must-read`
- [Mechanical execution overrides](./docs/ai/mechanical_overrides.md) `must-read`
- [Rails/RSpec conventions and repo rules](./docs/ai/rails-conventions.md) `must-read`
- [Secrets handling policy](./docs/ai/secrets.md) `must-read`
- [Code References](docs/ai/reference.md) `must-read`
- [Testing and verification](./docs/ai/testing.md) `must-read`

### Standards & Style
- [Code Style](docs/ai/code-style.md) `must-read`
- [Quality criteria checklist](./docs/ai/quality/criteria.md) `must-read`
- [Quality gate and review cadence](./docs/ai/quality_gate.md) `must-read`
- [Security Triage & PoC Templates](./docs/ai/testing.md#security-vulnerability-reproduction-poc) `must-read`

### Domain Knowledge (Load when relevant)
- [Knowledge architecture and domain logging](./docs/ai/knowledge_architecture.md) `context`
- [Decision journal workflow](./docs/ai/decision_journal.md) `context`
- [Candidates to remove from legacy guidance](./docs/ai/deletion_candidates.md) `context`
