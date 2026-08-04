# Tasks: document-ecosystem-plugin-bindings

## 1. Capability spec

- [x] 1.1 Add `openspec/specs/ecosystem-plugin-bindings/spec.md` via the change delta — the nine
      binding requirements, each with named consumers and scenarios.
- [x] 1.2 `openspec validate 2026-08-05-document-ecosystem-plugin-bindings --strict` passes.

## 2. Reference inventory

- [x] 2.1 Add `docs/ai/ecosystem.md`: the 22-repository table, hardening hazards, the no-consumer
      list, and the missing-API list.
- [x] 2.2 Add the `ecosystem-plugin-bindings` / `docs/ai/ecosystem.md` row to the `AGENTS.md` §5
      loading table.

## 3. Fold the survey back into the audit

- [x] 3.1 In `REGRESSION-AUDIT-2026-08-03.md`, mark M23 as ecosystem-confirmed (live consumer:
      `camaleon-ecommerce`), and record the four reversed dispositions (M22 escape→sanitize,
      M16 ivar dropped, M26 coercion site, M29 document-only) with the evidence.
- [x] 3.2 Add the survey-found engine defects as new audit candidates (N2 `before_upload` post-scan
      seam, N3 `dependent: :delete_all` on custom fields, N4 missing `private_file_path`).

## 4. Ship

- [x] 4.1 `(cd spec/dummy && bin/rails zeitwerk:check)` — no code changed, tree loads clean. Lint
      not applicable (no `.rb` touched); `bin/rspec` unaffected (no behaviour change).
- [x] 4.2 Archive this change on the branch (syncs the capability into `openspec/specs/`).
- [x] 4.3 Commit, push, open the PR, then add the changelog entry referencing it.
