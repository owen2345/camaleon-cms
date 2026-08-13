# Document the security remedy rule (reject, don't transform)

## Why

The maintainer's remedy rule — untrusted users' dangerous content is scanned and rejected at save,
never sanitized or otherwise transformed — was applied across the Tier-3 changes but recorded only
inside those changes. An agent or contributor starting from the standing docs would still find the
old guidance ("user input is sanitized appropriately" in the quality criteria) and could ship a
transform remedy in good faith. The rule needs to live where work starts: the agent entry point,
the development workflow, the quality checklist, the permissions doc, and the codified
security-capability-gating capability.

## What Changes

- `AGENTS.md` §1 gains the remedy rule alongside the security-fix testing rule.
- `docs/ai/workflows.md` Phase 2B states the operative rule for shaping fixes (save-time refusal,
  no render-time sanitization, opt-outs, scan task, what counts as a gate-free escaped position).
- `docs/ai/criteria.md` replaces "User input is sanitized appropriately" — which now contradicts
  the model — with the rejection criterion.
- `docs/security/permissions.md` gains "The remedy rule: reject, don't transform" next to the
  gating rule it complements, naming the shared detector, the model-level gates, the trust and
  opt-out semantics, and the history-is-reported-not-rewritten stance.
- `openspec/specs/security-capability-gating/spec.md` gains an ADDED requirement making the rule
  checkable for future proposals, the same way the gating rule itself is.

Documentation-only: no code paths change.
