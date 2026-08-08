# Tasks: security-capability-gating

## 1. Capability spec

- [x] 1.1 Author `specs/security-capability-gating/spec.md` with the default-off, fail-closed,
      authorization-not-proxy, and conform-new-capabilities requirements, citing the four existing
      permissions as conformant examples.

## 2. Docs

- [x] 2.1 Add a "The gating rule" section to `docs/security/permissions.md` above the per-permission
      detail: the rule, the admin bypass, default-off seeding, the fail-closed predicate, and the
      recipe for adding a new gated capability.
- [x] 2.2 Add a Security-section line to `docs/ai/criteria.md` pointing at the rule.

## 3. Ship

- [x] 3.1 `openspec validate --strict` on the new capability; `(cd spec/dummy && bin/rails zeitwerk:check)`
      (no code changed). Lint and `bin/rspec` not applicable — docs + spec only.
- [x] 3.2 Archive on the branch (syncs the capability into `openspec/specs/`).
- [x] 3.3 Commit, push, open the PR, then add the changelog entry referencing it.
