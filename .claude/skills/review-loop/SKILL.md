---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin/theme checkout (/code-review --fix with a ledger, verdict rules, the AGENTS.md checks and a PASS line). Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on a PR's local branch until they converge. Each pass reviews, applies what the verdicts allow, runs the checks and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill can't start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level>, one pass per turn, each turn ending with its PASS line, until the latest PASS line says STOP or a PASS line shows 8/8. A STOP for convergence counts only if the latest PASS line shows CLEAN and the one before it SETTLED or CLEAN, both with git status clean, rspec 0 failures and every check ok. A STOP for any other reason the skill gives (setup, a second conflict, an undone commit, a check it can't fix) counts as it stands.
```

## Parameters

Read them from the goal, the skill's arguments or the request; each has a default.

- **repo:** the checkout's directory name: `camaleon-cms` (default: the session's own checkout) or a sibling checkout such as `camaleon-cms-seo`, at `../<repo>` from camaleon-cms. The session always stays in camaleon-cms, where this harness lives.
- **pr:** the PR number in that repo's GitHub project. Default: the PR of the checkout's current branch.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Not `ultra`: that cloud review can only be launched by the user.

## Setup (first pass of a run)

- **Target:** resolve the checkout path, its GitHub project (`gh repo view --json nameWithOwner --jq .nameWithOwner`, run in the checkout) and the PR's head and base branches (`gh pr view <pr> --repo <project> --json headRefName,baseRefName`). The checkout must be on the head branch and not behind `origin/<head>` after a fetch; otherwise stop and say so, without switching or pulling, in a `PASS 0/8` line.
- **Commands** run against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`.
- **Ledger:** `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms, whatever the target repo, never committed. If it doesn't exist, create it and seed it as pass 0 from the refuted and skipped entries in the PR's memory entry, if there is one (skips fixed later are FIXED). Each run appends `## Run <date>, effort <level>` and counts its passes from 1; rows of earlier runs still count for the verdict checks.
- **Spec set:** the spec files the branch adds or changes (`git -C <checkout> diff --name-only <base>...HEAD -- spec/`) plus the adjacent specs as camaleon-cms `AGENTS.md` defines them. Write it at the top of the run.

Every pass starts by loading these rules fresh, noting HEAD and reading the ledger (it holds the pass count and each pass's state).

## Pass

Run `/code-review <effort> --fix` on the checkout's local branch against the base, unpushed commits included: no target for camaleon-cms, the checkout path for another repo. Its scope is `git -C <checkout> diff <base>...HEAD` plus any working-tree changes, whatever range `/code-review` picks on its own (at medium, `@{upstream}...HEAD`: on a pushed branch, only this run's commits). Never target the PR number: that may review the pushed head, which lacks this run's commits. If the review can't cover that whole range, stop and say so. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function or spec example (no line numbers) | category | verdict | evidence (fix SHA, or reason + the HEAD it was judged at)

## Verdicts

Checked in order; only FIXED is applied, and no finding is left without a verdict:

1. Refuted → REFUTED. PLAUSIBLE → DEFERRED.
2. Same claim as a DECISION or REFUTED row, on code no commit has touched since → REPEAT if DECISION, CONFLICT if REFUTED. If that code changed, treat the claim as new.
3. Its fix would undo a commit already on this branch (`<base>..HEAD`) or go against a DECISION row → CONFLICT.
4. Needs a design trade-off or the user's call → DECISION.
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED, own commit. A fix that preserves behavior is proven by the checks and needs no new spec; one that changes behavior, as a conventions fix can, gets its own spec; a coverage-only fix is the new spec. DEFERRED instead once step 5 is frozen (see below); a cleanup is also DEFERRED when another cleanup already reshaped that function or spec example in this run.
6. Altitude or wording → FIXED in pass 1 (own commit), DEFERRED after.
7. A correctness or security defect → FIXED: own spec, own commit (`docs/ai/workflows.md` Phase 3).

## Checks

After each pass, in the foreground and in the checkout, the four checks in camaleon-cms `AGENTS.md` "Verify before pushing", with rubocop first: `bin/rubocop -A` on the Ruby files the pass touched, then plain `bin/rubocop`, because autocorrect can rewrite string literals the specs must see. A check the repo doesn't have (the plugins carry no brakeman) is skipped and reported as n/a.

- rspec runs the run's spec set plus the specs of any code the pass touched outside it (add them to the set). Judge it by the "0 failures" line, never a piped exit status.
- Add `openspec validate --specs --strict` when the branch touches `openspec/`.
- Fix and commit any failure before the pass ends.
- Only one `bin/rspec` per test DB at a time, subagents included: a subagent that must run specs uses `DATABASE_URL=sqlite3:<scratchpad>/db_<name>.sqlite3`.

## Pass states and stop

- **SETTLED:** the pass ran to the end, applied no correctness or security fix (a failing spec fixed during the pass counts as one; step 5 fixes and lint fixes may land), every check passed and the checkout's tree is clean.
- **CLEAN:** SETTLED, and applied nothing at all (HEAD unchanged).
- **UNSETTLED:** anything else.

Step 5 freezes after the first SETTLED pass of the run, and in pass 8: from then on, its findings are DEFERRED. A converged run therefore ends on a pass that applied nothing, and every change it made was reviewed by a later pass.

Stop when the latest pass is CLEAN and the one before it SETTLED or CLEAN (converged), after pass 8 (report it as not converged), at a second CONFLICT on the same claim, when a pass's diff undoes an earlier commit on this branch, or on a check failure you can't fix. For a conflict, show both sides.

Commit but don't push during the run. On STOP: push the checkout's branch once, fold the PR body (`gh pr edit <pr> --repo <project>`, per `docs/ai/workflows.md`), add the new REFUTED and DECISION rows to the PR's memory entry if it has one, and report the DEFERRED, DECISION and CONFLICT rows.

## PASS line

The goal's evaluator reads only the transcript, so end every turn with:

PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason>
