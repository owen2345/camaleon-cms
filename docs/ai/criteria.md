# Quality Criteria

Before marking a task complete:

- The four CI-parity commands in `AGENTS.md` pass, with no new RuboCop offenses.
- New behavior has specs; a bug fix includes the spec that would have caught it.
- Security: SQL is parameterized; nothing evaluates user input (the gated `select_eval` field is the one deliberate exception); untrusted content is rejected at save, never transformed, and a new security-sensitive action is admin-only or behind a dedicated default-off permission — `docs/security/permissions.md`, "The remedy rule" and "The gating rule".
- Camaleon: plugins and themes follow the bundled ones under `app/apps/`; extension points are hooks, not patches; custom fields go through the existing field pipeline; public helpers, hooks and ivars that external consumers bind to keep their contracts (`docs/ai/ecosystem.md`).
