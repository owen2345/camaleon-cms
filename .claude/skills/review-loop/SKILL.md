---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin/theme checkout (/code-review --fix with a ledger, verdict rules, the AGENTS.md checks and a PASS line). Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on a PR's local branch until they converge. Each pass reviews, applies what the verdicts allow, runs the checks and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill can't start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level>, one pass per turn, each turn ending with its PASS line, until the latest PASS line says STOP or shows 8/8. A STOP for convergence counts only if the latest PASS line shows CLEAN and the one before it SETTLED or CLEAN, both with git status clean, rspec 0 failures and no errors (n/a for an empty spec set) and every check ok or n/a. A STOP for any other reason the skill gives (setup, a review that can't cover its range, a second conflict, an undone commit, a check it can't fix) counts as it stands.
```

The session loads this skill from its own checkout, so for a camaleon-cms PR the head branch must contain it: merge `origin/<base>` into an older branch before typing the goal. A PR that edits this skill runs from a copy saved outside the checkout, named in the goal in place of the skill, so its fixes don't change the rules mid-run.

## Parameters

Read them from the goal, the skill's arguments or the request; each has a default.

- **repo:** the checkout's directory name: `camaleon-cms` (default: the session's own checkout) or a sibling checkout such as `camaleon-cms-seo`, at `../<repo>` from camaleon-cms. The session always runs in the main camaleon-cms checkout, where this harness and the ledgers live: from an app-made worktree of it (`.claude/worktrees/<name>`), `../<repo>` and the ledger would resolve inside that worktree, and the ledger would be deleted with it.
- **pr:** the PR number in that repo's GitHub project. Default: the PR of the checkout's current branch.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Not `ultra`: that cloud review can only be launched by the user.

## Setup (first pass of a run)

- **Target:** resolve the checkout path, its GitHub project (`gh repo view --json nameWithOwner --jq .nameWithOwner`, run in the checkout) and the PR's head and base branches (`gh pr view <pr> --repo <project> --json headRefName,baseRefName`), then fetch both (`git -C <checkout> fetch origin <head> <base>`). The checkout must be on the head branch, not behind `origin/<head>` and clean (`git -C <checkout> status --porcelain` prints nothing); otherwise stop and say so, without switching, pulling, stashing or committing, in a `PASS 0/8` line. Every range below starts at `origin/<base>`, never the local base branch, which can lag behind. In a fork checkout, where `origin` is a fork and another remote is the project (`git -C <checkout> remote -v`, often `upstream`), the fork's `<base>` can lag the same way: fetch `<base>` from the project's remote and use its ref wherever `origin/<base>` appears, while the head, the setup guard and the STOP push stay on `origin`.
- **Commands** run against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`.
- **Ledger:** `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms, whatever the target repo, never committed. If it doesn't exist, create it and seed it as pass 0 from the PR's memory entry, if there is one: the REFUTED and DECISION rows every STOP adds there, then any other refuted entry as REFUTED and any skipped one as DECISION, or FIXED if it was fixed later. Each run appends `## Run <date>, effort <level>` and counts its passes from 1; rows of earlier runs still count for the verdict checks.
- **Spec set:** the spec files the branch adds or changes (`git -C <checkout> diff --name-only --diff-filter=d origin/<base>...HEAD -- 'spec/*_spec.rb'`: handed to `bin/rspec`, a deleted spec, a factory or a fixture fails to load, and a support file loads again and adds no example) plus the adjacent specs as camaleon-cms `AGENTS.md` defines them, which for a changed factory or support file are the specs that use the factories or helpers it changes. Write it at the top of the run.

Every pass starts by loading these rules fresh, noting HEAD and reading the ledger (it holds the pass count and each pass's state).

## Pass

Run `/code-review <effort> --fix` on the checkout's local branch against the base, unpushed commits included: no target for camaleon-cms, the checkout path for another repo. Its scope is `git -C <checkout> diff origin/<base>...HEAD` plus any working-tree changes, whatever range `/code-review` picks on its own (it may pick `@{upstream}...HEAD`, which on a pushed branch holds only this run's commits). Never target the PR number: that may review the pushed head, which lacks this run's commits. If the review can't cover that whole range, stop and say so. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function or spec example (no line numbers) | category | verdict | evidence (fix SHA, or reason + the HEAD it was judged at)

## Verdicts

Checked in order; only FIXED is applied, and no finding is left without a verdict. A finding that is also a correctness or security defect skips steps 5 and 6, whatever its category, and goes to step 7:

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED; low severity or a loud failure is no reason to defer a confirmed defect.
2. Same claim as a DECISION or REFUTED row, on code no commit has touched since → REPEAT if DECISION, CONFLICT if REFUTED. If that code changed, treat the claim as new.
3. Its fix would undo a commit already on this branch (`origin/<base>..HEAD`) or go against a DECISION row → CONFLICT.
4. Needs a design trade-off or the user's call → DECISION.
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED, own commit. A fix that preserves behavior is proven by the checks and needs no new spec; one that changes behavior, as a conventions fix can, gets its own spec; a coverage-only fix is the new spec. DEFERRED instead once step 5 is frozen (see below); a cleanup is also DEFERRED when another cleanup already reshaped that function or spec example in this run.
6. Altitude or wording → FIXED in pass 1 (own commit), DEFERRED after.
7. A correctness or security defect → FIXED: own spec, own commit (`docs/ai/workflows.md` Phase 3).

## Checks

After each pass, in the foreground and in the checkout, the four checks in camaleon-cms `AGENTS.md` "Verify before pushing", with rubocop first: `bin/rubocop -A` on the Ruby files the pass touched, then plain `bin/rubocop`, because autocorrect can rewrite string literals the specs must see. A check the repo doesn't have (the plugins carry no brakeman) is skipped and reported as n/a.

- rspec runs the run's spec set plus the specs of any code the pass touched outside it (add them to the set). Judge it by the summary line, never a piped exit status: it passes only with 0 failures and no error outside of examples, since a spec file that fails to load stops every example and still prints `0 examples, 0 failures, 1 error occurred outside of examples`. While the set is empty (a docs-only branch), skip it and report rspec as n/a: `bin/rspec` with no files runs the whole suite.
- Add `openspec validate --all --strict` when the branch touches `openspec/` (`--specs` alone skips a change not yet archived).
- Fix and commit any failure before the pass ends.
- Only one `bin/rspec` per test DB at a time, and the suite's `before(:suite)` empties every table. Other sessions and the IDE share the checkout's test DB, so the loop runs its specs on a scratch one (`DATABASE_URL=sqlite3:<scratchpad>/db_<name>.sqlite3`), and each subagent that must run specs on its own.

## Pass states and stop

- **SETTLED:** the pass ran to the end, applied no correctness or security fix (a failing spec fixed during the pass counts as one; step 5 fixes and lint fixes may land), every check passed and the checkout's tree is clean.
- **CLEAN:** SETTLED, and applied nothing at all (HEAD unchanged).
- **UNSETTLED:** anything else.

Step 5 freezes after the first SETTLED pass of the run, and in pass 8: from then on, its findings are DEFERRED. A converged run therefore ends on a pass that applied nothing, and every change it made was reviewed by a later pass.

Stop when the latest pass is CLEAN and the one before it SETTLED or CLEAN (converged), after pass 8 (report it as not converged), at a second CONFLICT on the same claim, when a pass's diff undoes an earlier commit on this branch, or on a check failure you can't fix. For a conflict, show both sides.

Commit but don't push during the run. The STOP push carries every commit of the run, and GitHub reads the skip-ci directive off its last commit alone, so decide that directive for the whole push (`docs/ai/workflows.md` Phase 3): a marked docs-only last commit also skips CI for the run's code commits. On STOP: push the head branch once (`git -C <checkout> push origin <head>`) and fold the PR body (`gh pr edit <pr> --repo <project>`, per `docs/ai/workflows.md`), except at setup, which has nothing to push, and after a check failure you can't fix or an undone commit: those stay unpushed for the user, since `AGENTS.md` verifies before pushing and an undo is theirs to judge. So does a push rejected because `origin/<head>` moved during the run: leave the PR body unfolded and say so, without pulling, rebasing or forcing, which would push a tree the checks never ran on or drop the other commits. On every STOP, add the new REFUTED and DECISION rows to the PR's memory entry if it has one, and report the DEFERRED, DECISION and CONFLICT rows.

## PASS line

The goal's evaluator reads only the transcript, so end every turn with the line below. Append it to the ledger too: the next pass reads the pass count and each pass's state there, and a pass without findings leaves no row. A STOP for convergence quotes the previous pass's PASS line from the ledger just above its own, since compaction can drop that turn from the transcript the evaluator reads.

PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason>
