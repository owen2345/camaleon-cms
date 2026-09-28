---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin/theme checkout (/code-review --fix with a ledger, verdict rules, the AGENTS.md checks and a PASS line). Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on a PR's local branch until they converge. Each pass reviews, applies what the verdicts allow, runs the checks and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill can't start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level>, one pass per turn, each turn ending with its PASS line, until the latest PASS line says STOP or shows 8/8. A STOP for convergence counts only if the latest PASS line shows CLEAN and the one before it, from the same run, SETTLED or CLEAN, both with git status clean, rspec 0 failures and no errors (n/a for an empty spec set or a no-code branch) and every check ok or n/a. A STOP for any other reason the skill gives (setup, a checkout changed between passes, a pass that ends with uncommitted changes, a review that can't cover its range, a second conflict, an undone commit, a check it can't fix) counts as it stands.
```

The session loads this skill live from its checkout, so every run works from a copy saved outside it, named in the goal in place of the skill or saved by setup (see **Rules** under Setup): its rules then don't change mid-run.

## Parameters

Read them from the goal, the skill's arguments or the request; each has a default.

- **repo:** the checkout's directory name: `camaleon-cms` (default: the session's own checkout) or a sibling checkout such as `camaleon-cms-seo`, at `../<repo>` from camaleon-cms. The session always runs in the main camaleon-cms checkout, where this harness and the ledgers live: from an app-made worktree of it (`.claude/worktrees/<name>`), `../<repo>` would resolve under `.claude/worktrees/` and the ledger inside the worktree, deleted with it. A core PR runs in that main checkout, which the user switches to its head branch (setup never does): the skill has no worktree option, by decision, since worktrees are very inconvenient in JetBrains IDEs.
- **pr:** the PR number in that repo's GitHub project. Default: the PR of the checkout's current branch.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Not `ultra`: that cloud review can only be launched by the user.

## Setup (first pass of a run)

- **Target:** resolve the checkout path, its GitHub project (`gh repo view --json nameWithOwner --jq .nameWithOwner`, run in the checkout; in a fork checkout, as below, give it `<remote>`'s URL, since gh answers with origin, the fork, unless that remote is named `upstream` or `github`) and the PR's state, head and base branches and head commit (`gh pr view <pr> --repo <project> --json state,headRefName,baseRefName,headRefOid`), then fetch both (`git -C <checkout> fetch origin <head> <base>`). The PR must be open, `origin/<head>` at its head commit (a PR from another fork fails this: the STOP push goes to `origin`) and the checkout on the head branch, not behind `origin/<head>` and clean (`git -C <checkout> status --porcelain` prints nothing); otherwise stop and say so, without switching, pulling, stashing or committing, in a `PASS 0/8` line. Every range below starts at `<base-ref>`: `origin/<base>`, never the local base branch, which can lag behind. In a fork checkout, where `origin` is a fork and another remote, `<remote>`, is the project (`git -C <checkout> remote -v`; often `upstream`), the fork's `<base>` can lag the same way, so `<base-ref>` is `<remote>/<base>`, fetched from it (`git -C <checkout> fetch <remote> <base>`), while the head, the setup guard and the STOP push stay on `origin`.
- **Commands** run against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`.
- **Ledger:** `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms, whatever the target repo, never committed. While it holds no `## Run` header (it may not exist yet, or hold only the `PASS 0/8` line of a setup that stopped before this step), create it if needed and seed it as pass 0 from the PR's memory entry, if there is one: the REFUTED and DECISION rows every STOP adds there, then any other refuted entry as REFUTED and any skipped one as DECISION, or FIXED if it was fixed later. Each run appends `## Run <date>, effort <level>`, then the HEAD setup found, and counts its passes from 1; rows of earlier runs still count for the verdict checks.
- **Rules:** every run works from a copy of this skill, since the live one follows its checkout: a PR that edits the skill changes it with each fix, and during a plugin run another session or the IDE can switch the camaleon-cms checkout, which the guard below doesn't cover. The copy is the skill as setup loads it; when the PR edits the skill, that is the head's version (`git -C <checkout> show HEAD:.claude/skills/review-loop/SKILL.md`), which a copy the goal names must match, since one left from an earlier run holds rules the PR has since changed; otherwise stop and say so in the `PASS 0/8` line. When the goal names the skill itself, save the copy to the session's scratchpad (`… > <scratchpad>/review-loop.md`). Either way, write the copy's path at the top of the run: every pass loads the rules from it.
- **Spec set:** the spec files the branch adds or changes (`git -C <checkout> diff --name-only --diff-filter=d <base-ref>...HEAD -- 'spec/*_spec.rb'`: handed to `bin/rspec`, a deleted spec, a factory or a fixture fails to load, and a support file loads again and adds no example) plus the adjacent specs as camaleon-cms `AGENTS.md` defines them, which for a changed factory or support file are the specs that use the factories or helpers it changes. Write it at the top of the run.

Every pass starts by loading these rules fresh (from the run's copy, if the ledger names one), noting HEAD and reading the ledger: this run's section, which holds the pass count and each pass's state, and the REFUTED and DECISION rows before it, pass 0's seed included, which the verdicts check. From pass 2 on, it also checks that the checkout is still on the head branch, clean and at the HEAD the previous PASS line ends on, since other sessions and the IDE share it: a switch, edit or commit made between passes would otherwise be reviewed and committed as the run's work, or pushed under checks copied from another tree. Commits past that HEAD whose SHAs the ledger's rows after that line record are the run's own, left by a pass cut off before its PASS line: finish that pass instead of starting a new one. A pass 1 cut off that way, whose run header is the ledger's last with no PASS line under it, is finished the same way against the HEAD that header records, without setting the run up again. Anything else stops the run: say so, without switching, resetting, stashing or committing.

## Pass

Run `/code-review <effort> --fix` on the checkout's local branch against the base, unpushed commits included: no target for camaleon-cms, the checkout path for another repo. Its scope is `git -C <checkout> diff <base-ref>...HEAD`, whatever range `/code-review` picks on its own (it may pick `@{upstream}...HEAD`, which holds only the commits not yet pushed). Never target the PR number: that may review the pushed head, which lacks this run's commits. If the review can't cover that whole range, stop and say so. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function or spec example (no line numbers) | category | verdict | evidence (fix SHA, or reason + the HEAD it was judged at)

Append each row when its verdict is reached, a FIXED row in the same command as its commit; a check fix's commit gets a row too, with the check as its category. A pass cut off before its PASS line then leaves every commit it made on record.

## Verdicts

Checked in order, except that a finding that is also a correctness or security defect skips steps 5 and 6, whatever its category, and goes to step 7. Only FIXED is applied, each fix committed on its own once its specs pass and the `AGENTS.md` checks are clean for what it touched (`docs/ai/workflows.md` Phase 3), and no finding is left without a verdict.

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED; low severity or a loud failure is no reason to defer a confirmed defect.
2. Same claim as a DECISION or REFUTED row, on code no commit has touched since → REPEAT if DECISION, CONFLICT if REFUTED. If that code changed, treat the claim as new.
3. Its fix would undo a commit already on this branch (`<base-ref>..HEAD`) or go against a DECISION row → CONFLICT.
4. Needs a design trade-off or the user's call → DECISION.
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED, own commit. A fix that preserves behavior is proven by the checks and needs no new spec; one that changes behavior, as a conventions fix can, gets its own spec; a coverage-only fix is the new spec. DEFERRED instead once step 5 is frozen (see below); a cleanup is also DEFERRED when another cleanup already reshaped that function or spec example in this run.
6. Altitude or wording → FIXED in pass 1 (own commit), DEFERRED after. Wording is text that still gives the right outcome when followed literally; text that gives a wrong one is a defect.
7. A correctness or security defect → FIXED: own spec, own commit (`docs/ai/workflows.md` Phase 3).

## Checks

After each pass, in the foreground and in the checkout, the four checks in camaleon-cms `AGENTS.md` "Verify before pushing", with rubocop first: `bin/rubocop -A` on the Ruby files the pass touched, then plain `bin/rubocop`, because autocorrect can rewrite string literals the specs must see. A check the repo doesn't have (the plugins carry no brakeman) is skipped and reported as n/a. A branch that changes no code, as that `AGENTS.md` section defines it, runs none of the four and reports each as n/a. A pass that applied nothing (HEAD unchanged, tree clean) runs no check either, `openspec validate` included: it copies the previous pass's rspec and checks fields into its own PASS line, since they were taken on the same tree; pass 1 of a run has no previous pass to copy from.

- rspec runs the run's spec set plus the specs of any code the pass touched outside it (add them to the set and to its line at the top of the run, which later passes read), or the whole suite while the branch carries a refactoring with a wide blast radius (a base class, a concern every model includes, a shared helper), as `AGENTS.md` says. Judge it by the summary line, never a piped exit status: it passes only with 0 failures and no error outside of examples, since a spec file that fails to load stops every example and still prints `0 examples, 0 failures, 1 error occurred outside of examples`. While the set is empty, skip it and report rspec as n/a: `bin/rspec` with no files runs the whole suite.
- Add `openspec validate --all --strict` when the branch touches `openspec/` (`--specs` alone skips a change not yet archived).
- When a check fails, fix it. After that fix, or when `bin/rubocop -A` corrects a file (it exits 0 once it corrects every offense, so no check fails), commit the change and run the checks again before the pass ends: the PASS line reports runs taken on the pass's final HEAD, which a later pass may copy.
- Only one `bin/rspec` per test DB at a time, and the suite's `before(:suite)` empties every table. Other sessions and the IDE share the checkout's test DB, so the loop runs its specs on a scratch one (`DATABASE_URL=sqlite3:<scratchpad>/db_<name>.sqlite3`), and each subagent that must run specs on its own.

## Pass states and stop

- **SETTLED:** the pass ran to the end, applied no correctness or security fix (a failing spec fixed during the pass counts as one; step 5 and step 6 fixes and lint fixes may land), every check passed or was n/a and the checkout's tree is clean.
- **CLEAN:** SETTLED, and applied nothing at all (HEAD unchanged).
- **UNSETTLED:** anything else.

Step 5 freezes after the first SETTLED pass of the run, and in pass 8: from then on, its findings are DEFERRED. A converged run therefore ends on a pass that applied nothing, and every change it made was reviewed by a later pass.

Stop and push when the latest pass is CLEAN and the run's pass before it SETTLED or CLEAN (converged), after a pass 8 that didn't converge (report it as not converged), at a second CONFLICT on the same claim (show both sides) or when a review can't cover its range. Stop without pushing at setup, when the checkout changed between passes, when a pass ends with uncommitted changes (the run commits all its own work, so they may be another writer's), when a pass's diff undoes an earlier commit on this branch or on a check failure you can't fix, even when a reason to push also applies: those stay unpushed for the user, since `AGENTS.md` verifies before pushing and an undo or another writer's change is theirs to judge.

Commit but don't push during the run. The STOP push carries every commit of the run, and GitHub reads the skip-ci directive off its last commit alone, so decide that directive for the whole push (`docs/ai/workflows.md` Phase 3): a marked docs-only last commit also skips CI for the run's code commits. At a stop that pushes, push the head branch once (`git -C <checkout> push origin <head>`) and fold the PR body (`gh pr edit <pr> --repo <project>`, per `docs/ai/workflows.md`), provided the run has taken the checks on that HEAD, or found them n/a there, the stopping pass included: a review that can't cover its range in pass 1 stops before any check, so it pushes nothing. A push rejected because `origin/<head>` moved during the run stays unpushed too, and so does a PR merged or closed during it (check its `state` again before pushing): leave the PR body unfolded and say so, without pulling, rebasing or forcing, which would push a tree the checks never ran on or drop the other commits. On every STOP, add the new REFUTED and DECISION rows to the PR's memory entry if it has one, and report the DEFERRED, DECISION and CONFLICT rows.

## PASS line

The goal's evaluator reads only the transcript, so end every turn with the line below. Append it to the ledger too: the next pass reads the pass count and each pass's state there, and a pass without findings leaves no row. A STOP for convergence quotes the previous pass's PASS line from the ledger just above its own, since compaction can drop that turn from the transcript the evaluator reads.

```text
PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason>
```
