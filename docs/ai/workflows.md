# Workflows

## Local Setup
```bash
mise install
bundle install
bin/rails db:prepare
```

## Verification Pointer
- Test and verification commands live in `docs/ai/testing.md`.

## CI Parity Notes
- CI runs security scans and lint from `.github/workflows/ci.yml`:
    - `bin/brakeman --no-pager`
    - `bin/bundler-audit`
    - `bin/rubocop -f github`

## Branch and PR Flow
- Start from updated `main`.
- Create a dedicated branch per task.
- Push branch and open PR into `main`.
- Keep commits focused and reviewable.

## PR and Commit Description Rules
- Descriptions must summarise changes at a general level (what changed and why), not commit-by-commit.
- Descriptions must include one sentence on user-visible impact (or explicitly state there is no user-visible impact).
- Descriptions must not include a `Files Changed` section.
- Descriptions must not include test example/failure counts.
- Descriptions must not describe how verification was performed (commands run, environments used, or step-by-step validation details).
- Descriptions must not reference commit SHAs or commit history in the description.

## Task Start / Finish Checklist
- Before starting a new domain task, review relevant files from `docs/ai/knowledge/` and prior records in `docs/ai/decisions/`.
- While working, test whether any existing hypothesis can be confirmed or contradicted.
- Before marking a task complete, evaluate it against `docs/ai/quality/criteria.md`.
- See deeper guidance in `docs/ai/knowledge_architecture.md`, `docs/ai/decision_journal.md`, and `docs/ai/quality_gate.md`.
- Apply execution constraints from `docs/ai/mechanical_overrides.md` (step-0 clean-up, phased execution, edit integrity).

## When to Update Agent Docs
- If setup commands change, update `AGENTS.md`, this file, and `README.md` in the same PR.
- If test commands change, update `docs/ai/testing.md`, `AGENTS.md`, and `README.md` in the same PR.
- If CI commands change, update this file to match `.github/workflows/ci.yml`.
