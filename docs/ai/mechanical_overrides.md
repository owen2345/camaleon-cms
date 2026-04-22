# Agent Directives: Mechanical Overrides

These are strict execution directives for agent work in this repository.

## Pre-Work

1. **Step 0 rule**
    - Before any structural refactor on a file larger than 300 LOC, first remove dead props, unused exports, unused imports, and debug logs.
    - Commit this cleanup separately before the real refactor.

2. **Phased execution**
    - Do not attempt large multi-file refactors in one pass.
    - Break work into explicit phases.
    - Complete Phase 1, run verification, and wait for explicit approval before Phase 2.
    - Each phase should touch no more than 5 files.

## Code Quality

3. **Senior dev override**
    - If architecture is flawed, state is duplicated, or patterns are inconsistent, propose and implement structural fixes.
    - Do not stop at the minimally requested change when that would leave obvious design debt.

4. **Forced verification (project equivalent required)**
    - Do not report completion before running all relevant checks and fixing blocking errors.
    - For this Rails repo, use project-equivalent checks:

```bash
bin/rails zeitwerk:check
bin/rubocop
bin/rspec
```

- If a checker is not configured for the task context, state that explicitly.

## Context Management

5. **Sub-agent swarming**
    - For tasks touching more than 5 independent files, use parallel sub-agents where possible to reduce context decay.

6. **Context decay awareness**
    - After long conversations (10+ messages), re-read files before editing.
    - Do not rely on memory of file contents.

7. **File read budget**
    - For large files, read in chunks using offsets/limits instead of assuming one read is complete.

8. **Tool result blindness**
    - If command/search results seem suspiciously short, re-run with narrower scope.
    - State when truncation is suspected.

## Edit Safety

9. **Edit integrity**
    - Re-read each file before editing.
    - After edits, read/validate again to confirm the change applied correctly.
    - Avoid many consecutive edits to the same file without verification reads.

10. **No semantic search assumptions**
- For renames/identifier changes, search separately for:
    - direct calls and references
    - type-level references
    - string literals containing the name
    - dynamic imports/`require` calls
    - re-exports/barrel entries
    - tests and mocks
