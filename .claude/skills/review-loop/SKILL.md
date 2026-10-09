---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin, theme or host app checkout (/code-review --fix with a ledger, verdict rules, the AGENTS.md checks and a PASS line). Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on a PR's local branch until they converge. Each pass reviews, applies what the verdicts allow, runs the checks and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill can't start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level>, one pass per turn, until the latest PASS line's last field starts with STOP. Each turn ends with its PASS line, and a PASS line that ends in continue never meets this goal, whatever its state. A STOP for convergence counts only if the latest PASS line shows CLEAN and the one before it, from the same run, SETTLED or CLEAN. Both lines must show git status clean, rspec 0 failures and no errors, or n/a, and every check ok or n/a. A STOP for any other reason the skill gives (setup, pass 8 without convergence, a checkout changed between passes, a pass that ends with uncommitted changes, a review that cannot cover its range, a second conflict, a rewrite, a rebase conflict, a rewrite Phase 3 forbids, an undone commit, a check it cannot fix, a failure that was there before the branch, a CI failure the checkout does not show and a rerun shows again, a head with no checks) counts as it stands. A STOP that pushed counts only if its checks field shows ci as ok or n/a.
```

The session loads this skill live from its checkout, so every run works from a copy its checkout's changes don't reach, named in the goal in place of the skill or saved by setup (see **Rules** under Setup): its rules then don't change mid-run.

## Parameters

Read them from the goal, the skill's arguments or the request; each has a default.

- **repo:** the checkout's directory name: `camaleon-cms` (default: the session's own checkout) or a sibling checkout, a plugin or theme such as `camaleon-cms-seo` or a host app such as `florsan`, at `../<repo>` from camaleon-cms. The session always runs in the main camaleon-cms checkout, where this harness and the ledgers live: from an app-made worktree of it (`.claude/worktrees/<name>`), `../<repo>` would resolve under `.claude/worktrees/` and the ledger inside the worktree, deleted with it. A core PR runs in that main checkout, which the user switches to its head branch (setup never does): the skill has no worktree option, by decision, since worktrees are very inconvenient in JetBrains IDEs.
- **pr:** the PR number in that repo's GitHub project. Default: the PR of the checkout's current branch.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Not `ultra`: that cloud review can only be launched by the user.

## Setup (first pass of a run)

- **Target:** resolve the checkout path and its GitHub project: `gh repo view --json nameWithOwner --jq .nameWithOwner`, run in the checkout. In a fork checkout, as below, give that command the URL of `<remote>`. gh answers with `origin`, the fork, unless that remote is named `upstream` or `github`. Then read the PR: `gh pr view <pr> --repo <project> --json state,headRefName,baseRefName,headRefOid,headRepositoryOwner,headRepository` gives its state, its head and base branches, its head commit and its head repository. Then fetch both branches: `git -C <checkout> fetch origin <head> <base>`. In a fork checkout, only `<head>` comes from `origin`.

  The run goes on only when each condition below holds. Otherwise stop and say so in a `PASS 0/8` line. Do not switch, pull, stash or commit.
  - The PR is open.
  - The head of the PR is in the repository of `origin`: the `headRepositoryOwner` login and the `headRepository` name, as `<owner>/<name>`, equal `gh repo view <origin's URL> --json nameWithOwner --jq .nameWithOwner`. A PR from another fork fails this, because the STOP push goes to `origin`. Such a PR fails this also when `origin` has a branch of that name at that commit.
  - `origin/<head>` is at the head commit of the PR.
  - The checkout is on the head branch, at `origin/<head>`. The STOP push runs no check, so a commit that is not pushed must be a commit of the run, which ran its checks.
  - The checkout is clean: `git -C <checkout> status --porcelain` prints nothing.
  - The tests of the checkout are RSpec specs, the only suite the checks run: `git -C <checkout> ls-files 'test/*_test.rb'` prints nothing. A plugin still on minitest stops here.
  - The checkout has `bin/rubocop` and `bin/rspec`, which the checks run.

  Every range below starts at `<base-ref>`: `origin/<base>`, never the local base branch, which can lag behind. In a fork checkout, `origin` is a fork and another remote, `<remote>`, is the project (`git -C <checkout> remote -v`, often `upstream`). The `<base>` of the fork can lag the same way. So `<base-ref>` is `<remote>/<base>`, fetched from it (`git -C <checkout> fetch <remote> <base>`). The head, the setup guard and the STOP push stay on `origin`.
- **Commands** run against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`.
- **Ledger:** `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms, whatever the target repo, never committed. A ledger with no `## Run` header does not exist yet, or holds only the `PASS 0/8` line of a setup that stopped before this step. Only then create it, if needed, and seed it as pass 0 from the PR's memory entry, if there is one. The seed holds the REFUTED and DECISION rows that every STOP adds there. It also holds any other refuted entry as REFUTED, and any skipped entry as DECISION, or as FIXED when it was fixed later.

  Each run appends, in one command, `## Run <date>, effort <level>` and the line `setup HEAD <sha>`, the PR head that setup found. It counts its passes from 1. The rows of earlier runs still count for the verdict checks.
- **Rules:** every run works from a copy of this skill, since the live one follows its checkout: a PR that edits the skill changes it with each fix, and during a plugin run another session or the IDE can switch the camaleon-cms checkout, which the guard below doesn't cover. The copy is the skill as setup loads it; when the PR edits the skill, that is the head's version (`git -C <checkout> show HEAD:.claude/skills/review-loop/SKILL.md`), which a copy the goal names must match, since one left from an earlier run holds rules the PR has since changed; otherwise stop and say so in the `PASS 0/8` line. When the goal names the skill itself, save the copy beside the ledger (`… > tmp/review-loop/<repo>/<pr>.rules.md` in camaleon-cms), which lasts as long as the run: the session's scratchpad is shared by every run in the session and gone after a reboot, while a run can go on in a later session. Either way, write the copy's path at the top of the run: every pass loads the rules from it.
- **CI:** read the ci check of the `setup HEAD`, as **Checks** says, and append the line `setup ci <ok, n/a, no checks or the failed check>` to the ledger. A failed suite check there is the first failed check of the run: trace it as **Checks** says, before the review of pass 1. A head with no checks after five minutes stops the run: say so in the `PASS 0/8` line.

Every pass starts with three steps. It loads these rules fresh, from the run's copy when the ledger names one. It notes HEAD. It reads the ledger: the section of this run, which holds the pass count and the state of each pass. It also reads the REFUTED and DECISION rows before that section, the seed of pass 0 included. The verdicts check those rows.

A run is over when the last PASS line of the ledger is a STOP and no run header follows it. Then set up a new run.

From pass 2 on, the pass also checks the checkout. The checkout must still be on the head branch, clean and at the HEAD that the previous PASS line ends on. Other sessions and the IDE share the checkout. Without this check, a switch, an edit or a commit made between passes is reviewed and committed as the work of the run. Or the push carries it under checks taken on another tree.

Commits past that HEAD are the run's own when the ledger rows after that line record their SHAs. A pass cut off before its PASS line left them: finish that pass instead of a new one. A HEAD that a `rebase to` line after that PASS line names is also the run's own. That pass rewrote its commits: finish it with its PASS line and the STOP push.

A pass 1 can be cut off that way: its run header is the last of the ledger, with no PASS line under it. Finish it the same way against the `setup HEAD` under that header, without a new setup. When no Rules line is under that header, the setup was cut off before it: make the rules copy first. When no `setup ci` line is under it, read the ci check of setup first.

Anything else stops the run: say so. Do not switch, reset, stash or commit. When the commits of the branch changed, also tell the user to start a new run. A rebase onto the base is one example. The user must push the branch before that run, because setup stops on a checkout that is not at `origin/<head>`. A rewrite of pushed commits needs the lease of `docs/ai/workflows.md` Phase 3.

## Pass

Run `/code-review <effort> --fix` on the checkout's local branch against the base, unpushed commits included: no target for camaleon-cms, the checkout path for another repo. Its scope is `git -C <checkout> diff <base-ref>...HEAD`, whatever range `/code-review` picks on its own (it may pick `@{upstream}...HEAD`, which holds only the commits not yet pushed). Never target the PR number: that may review the pushed head, which lacks this run's commits. If the review can't cover that whole range, stop and say so. For another repo, the review's conventions angle holds the code to camaleon-cms's `CLAUDE.md` (`AGENTS.md`): plugin, theme and host app checkouts carry no agent docs of their own, and a CLAUDE.md governs only the files at or below its directory, so the angle would otherwise find none. `AGENTS.md`'s "Gem, not an app" and "Support range" rules are the gem's and don't bind a host app: its root `bin/rails` runs the app, which has no dummy, and it runs the one Rails and Ruby version it pins. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function, spec example or doc section heading (no line numbers) | category | verdict | evidence (fix SHA, or reason + the HEAD that it was judged at)

Append each row other than FIXED as soon as its finding gets a verdict. Append a FIXED row in the same command as the commit of its fix, which gives the row its SHA. The commit of a check fix also gets a FIXED row, with the check as its category. Because each commit command appends its rows, a pass cut off before its PASS line leaves every commit that it made on record.

A pass can rebase any commit of the branch, also a pushed one, with the fixup commits and the autosquash rebase of `docs/ai/workflows.md` Phase 3. A rewrite gives those commits new SHAs, so the rows and PASS lines no longer match the branch. A pass rewrites only after its last commit, then stops the run and pushes. Tell the user to start a new run.

## Verdicts

Check the steps in order. A finding that is also a correctness or security defect skips steps 5 and 6 and goes to step 7, whatever its category. The pass applies only FIXED and leaves no finding without a verdict. Commit the fixes as `docs/ai/workflows.md` Phase 3 says.

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED; low severity or a loud failure is no reason to defer a confirmed defect.
2. Same claim as a DECISION or REFUTED row, on code that the row's HEAD also has → REPEAT if DECISION, CONFLICT if REFUTED. The row's HEAD is the HEAD that it was judged at. A row that names no HEAD, such as a pass 0 seed, has the `setup HEAD` of the run header after it. If that code changed, treat the claim as new.

   Also treat it as new when the repository no longer has that HEAD (`git -C <checkout> cat-file -e <sha>` fails). A rewrite leaves the old HEAD off the branch, but the repository keeps it.
3. Its fix would undo a commit already on this branch (`<base-ref>..HEAD`) or go against a DECISION row → CONFLICT.
4. Needs a design trade-off or the user's call → DECISION.
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED. A fix that preserves behavior needs no new spec, because the checks prove it. A fix that changes behavior, as a conventions fix can, gets its own spec. A coverage-only fix is the new spec.

   Once step 5 is frozen (see below), the findings of step 5 are DEFERRED instead. A cleanup is also DEFERRED when a cleanup of an earlier pass of this run reshaped that function, spec example or doc section.
6. Altitude or wording → FIXED in pass 1, DEFERRED after. Wording is text that still gives the right outcome when a reader follows it literally. Text that gives a wrong outcome is a defect.
7. A correctness or security defect → FIXED, with the spec that reproduces it. `AGENTS.md` "Specs" and `docs/ai/workflows.md` Phase 3 give the exceptions. A docs-only or config-only fix needs no spec. When a spec is infeasible, the commit message says why.

## Checks

The checks are the four in camaleon-cms `AGENTS.md` "Verify before pushing". A plugin or theme runs `zeitwerk:check` from `spec/dummy` and has no brakeman, so brakeman is n/a there. A host app runs `zeitwerk:check` from its root. A check that `AGENTS.md` "Verify before pushing" exempts the branch or the commit from is also n/a.

Each commit runs the checks before it lands, the lint first, as `docs/ai/workflows.md` Phase 3 says. A pass that commits nothing runs no check. The PASS line reports the last run of each check in the pass, or n/a when the pass did not run it.

A foreground command ends at its timeout: two minutes by default, ten minutes at most. Give a long command the ten-minute timeout. A command that takes longer, such as a run of the whole suite, runs in the background, and the pass reads its log when the harness reports its end. Do not edit the checkout while a run is active in the background.

The fifth check is **ci**: the GitHub checks of the PR head. In camaleon-cms, they test the PR merged into the base, on every Ruby and Rails of the matrix. Setup reads them for the `setup HEAD`. A stop that pushes reads them again for the pushed commit (see **Pass states and stop**). The PASS line reports ci in its checks field like the other checks.

- `gh pr checks <pr> --repo <project> --json workflow,name,bucket,link` lists the checks of the PR head. A check with bucket `pending` is still active: wait with `gh pr checks <pr> --repo <project> --watch --interval 60 > /dev/null`, which ends when every check ends, and list again. Its output goes to `/dev/null`: in a log, it repeats the whole table at each interval. Give the wait the ten-minute timeout, and run it again until it ends on its own: the matrix takes about twenty minutes.
- `no checks reported` is n/a when the head commit carries the skip-ci marker or the repo has no workflow. For any other head, the checks appear a moment after the push: list again every 30 seconds (`sleep 30`), ten times at most. When no check appears in five minutes, GitHub made no run for the head. The PR has a merge conflict with the base, or a workflow file of the branch does not parse, for example. Report ci as `no checks`, and at setup stop the run (see **Pass states and stop**).
- The suite checks are the checks of the workflows that run the lint, the scans and the suite of the repo. In camaleon-cms, those are `Audit` and `Test supported versions`. In another repo, that is the workflow of `ci.yml`: `CI` in a plugin or theme, `test-on-push` in a host app. Every other check is advisory: the checks of `Test upcoming versions` (Rails edge and Ruby head) and of `Test ecosystem members`, and a check that a GitHub app adds, for example. A failure there gets a DECISION row and does not fail ci, but a failed suite check does.
- A check with bucket `fail` or `cancel` failed, and a check with bucket `pass` or `skipping` passed. The job log of a failed check (`gh run view <run id> --repo <project> --job <job id> --log-failed`, with both ids from its link) names the failed step, the failed examples and the `--seed`, if any.
- Run the failed check in the checkout as its step in `.github/workflows/` does. Use the Ruby and the gems of the checkout. For a spec failure, first run the failed examples alone. When they pass, run the files of the job with its `--seed`, if any. For a suite check of camaleon-cms, those files are the whole suite, which runs in the background. The loop runs the whole suite only here and in the trace of this failure, because the CI run was one.
- When the checkout shows the failure, it is no flake. The CI run and the checkout run are the two runs of `docs/ai/workflows.md` Phase 3. Find its cause as Phase 3 says, with the files that showed it, and fix it. With no fix uncommitted, the check fix is its own commit. Its FIXED row has `ci` as its category, and it counts as a correctness fix. When the failure was there before the branch (Phase 3, step 4), stop the run.
- When the checkout does not show the failure, the flake rule of Phase 3 does not apply: rerun the failed jobs once (`gh run rerun <run id> --repo <project> --failed`) and read the checks again. When the rerun passes, the failure was a flake that the checkout does not show. Give it a DECISION row, and ci is ok. When the rerun fails again, the failure needs the Ruby, the gems or the merge with the base of that job. Stop the run, and report the job, the failed examples and the link.

- A spec run before a commit runs the specs of the fix and the adjacent specs (`docs/ai/workflows.md` Phase 3), never the whole suite. Hand `bin/rspec` only `*_spec.rb` files that exist. A deleted spec, a factory or a fixture fails to load, and a support file loads again and adds no example. For a changed factory or support file, the adjacent specs are the specs that use the factories or helpers that it changes. When a commit has no such spec file, skip the run and report rspec as n/a. `bin/rspec` with no files runs the whole suite.
- Judge a spec run by the summary line, never a piped exit status. It passes only with 0 failures and no error outside of examples. A spec file that fails to load stops every example, and the run still prints `0 examples, 0 failures, 1 error occurred outside of examples`.
- Add `openspec validate --all --strict` and `openspec validate --archived` to the checks of a commit that touches `openspec/`. `--specs` alone skips a change not yet archived, and `--all` skips an archived one. Only `--archived` checks that an archived change has every task checked, as `docs/ai/workflows.md` Phase 4 wants before the branch merges. Given both flags, `validate` runs only the archived set.
- When a check fails, find out what caused the failure and fix it as `docs/ai/workflows.md` Phase 3 says. There, `<base-ref>` takes the place of `origin/<base>`. When the check fails in the same way at the start commit of the branch (Phase 3, step 4), stop the run. Leave the uncommitted fix in the tree, and name it in the report as the run's own.
- When a commit of the branch caused the failure, fix it and commit the fix as `docs/ai/workflows.md` Phase 3 says. The FIXED row of the fixup commit also names the commit that it fixes.
- Run the rebase that folds the fixup commits after the last commit of the pass, not before. A rewrite stops the run (see **Ledger rows**). Append the line `rebase to <new HEAD>` to the ledger in the same command as the rebase (`… && echo "rebase to $(git -C <checkout> rev-parse HEAD)" >> <ledger>`). When the pass has more than one fixup commit, `<sha>` is the oldest commit that they fix. The rebase folds only the fixups of `<sha>` and of later commits.
- A pass cut off before its rebase leaves a `fixup!` commit that is not folded. When the next turn finishes that pass (see **Setup**), it runs the rebase after its last commit.
- Start a spec run (`bin/rspec`), the loop's or a subagent's, only when no other run in the same checkout is active. Otherwise wait for it to end. `docs/ai/testing.md` allows no two runs at once: runs on separate databases still share the files of the dummy app, and can fail each other's specs. A failed run with another run active during it, which the signals below show, counts only once it fails again alone (`docs/ai/workflows.md` Phase 3).
  - `pgrep -f '[r]spec'`, in a command of its own, lists every run. Run it before every run, also in camaleon-cms: the line below does not show every run. The brackets keep the shell that runs the command off the list. The command line of that shell holds the pattern, and the pgrep of Linux does not drop that shell by itself. `ps -o args= -p <pid>` shows what each run is. `lsof -a -d cwd -p <pid>`, or `readlink /proc/<pid>/cwd` on Linux, shows the checkout that it runs in.
  - Other sessions and the IDE can still start a run during the loop's, on the test database of the checkout. The `before(:suite)` of the suite empties the tables of that database. So the loop runs its specs on a scratch database (`DATABASE_URL=sqlite3:<scratchpad>/db_<name>.sqlite3`), and so does each subagent that must run specs.
  - In camaleon-cms, the line at exit of the run is the main signal. It names the other Camaleon runs that were active during the run, also a run on a scratch database or a dry run (`rspec --dry-run`). Run the specs as `bin/rspec … > <log> 2>&1`, and read the line and the `RspecRunMarker:` warnings at the end of the log as `docs/ai/run-markers.md` says. No warning fails the run: judge the run by its summary line.
  - The line cannot show every run (`docs/ai/run-markers.md` lists them), and a process that is no run, such as `bundle exec rake app:db:test:prepare`, rewrites the test database too. So the test database of the checkout is the second signal: the loop runs on the scratch database, so only another process writes it. Before a run, `touch <scratchpad>/run-start`. After it, `find spec/dummy/db -name 'test.sqlite3*' -newer <scratchpad>/run-start` lists the files that another process changed during the run. A plugin suite leaves no run marker. There, `pgrep` at the start and at the end of the run and this file are the only signals.
  - A host app on PostgreSQL (camaleon_website, florsan) runs the specs on its own test database instead, which already exists. A sqlite3 URL switches its adapter, and its suite aborts on a database whose name does not end in `_test`. Other checkouts of that app use the same database. So a run in one of them counts as a run in the same checkout. That rule holds for the wait above and for the second run of Phase 3. The database of a host app is no file. There, `pgrep` at the start and at the end of a run is the only signal.
  - The second run of `docs/ai/workflows.md` Phase 3 is the run of the same files and the same `--seed`, with no other run active.

## Pass states and stop

- **SETTLED:** the pass ran to the end and applied no correctness or security fix. Every check passed or was n/a, and the checkout's tree is clean. The fix of a flake, or of a check failure that a commit of the branch caused, counts as a correctness fix. Step 5 and step 6 fixes can land.
- **CLEAN:** SETTLED, and applied nothing at all (HEAD unchanged).
- **UNSETTLED:** anything else.

Step 5 freezes after the first SETTLED pass of the run, and in pass 8: from then on, its findings are DEFERRED. A converged run therefore ends on a pass that applied nothing, and every change it made was reviewed by a later pass.

Stop and push in these cases:

- The latest pass is CLEAN and the run's pass before it SETTLED or CLEAN (converged).
- Pass 8 did not converge. Report it as not converged.
- A second CONFLICT on the same claim. Show both sides.
- A pass rewrote commits (see **Ledger rows**).
- A review cannot cover its range.

Stop and do not push in these cases, also when a reason to push applies:

- Setup stops, also on a PR head with no checks (see **Checks**).
- The checkout changed between passes.
- A pass ends with uncommitted changes. The run commits all its own work, so they can be another writer's.
- A pass's diff undoes an earlier commit on this branch.
- A rebase stops on a conflict. Run `git rebase --abort` first.
- `docs/ai/workflows.md` Phase 3 forbids a rewrite. For that rule, `<remote sha>` is the `setup HEAD` of the run header.
- A check fails, and you cannot fix it or the failure was there before the branch.
- A CI failure that the checkout does not show and that a rerun shows again (see **Checks**).

These commits stay unpushed for the user: `AGENTS.md` verifies before pushing, and an undo or another writer's change is for the user to judge. When Phase 3 forbids the rewrite, or the rebase stops on a conflict, the fixup commit stays unfolded. The report names that commit and the `git rebase --autosquash <sha>~1` that folds it. A stop without a push leaves the commits of the run for the user to push before the next run (see **Setup**).

Commit but do not push during the run. The STOP push carries every commit of the run. GitHub reads the skip-ci directive off the last commit of the push alone, so decide that directive for the whole push (`docs/ai/workflows.md` Phase 3). A marked docs-only last commit also skips CI for the code commits of the run. At a stop that pushes, push the head branch once and fold the PR body (`gh pr edit <pr> --repo <project>`, per `docs/ai/workflows.md`).

Each commit of the run ran the checks before it landed, so the push needs no other check run (`AGENTS.md` "Verify before pushing").

Before the push, fetch `origin/<head>`. When it is at HEAD, skip the push. When the run made a commit, the pass was cut off after its push: read ci for HEAD, as below. When the run made no commit, the ci read of setup stands.

Push with `git -C <checkout> push origin <head>`. When the run rewrote a pushed commit, the `setup HEAD` of the run header is no longer in the branch (`git -C <checkout> merge-base --is-ancestor <that sha> HEAD` fails). Only then push with `--force-with-lease=<head>:<that sha>` instead.

A push rejected because `origin/<head>` moved during the run stays unpushed too. So does a PR merged or closed during the run: check its `state` again before the push. Leave the PR body unfolded and say so. Do not pull, rebase or force past the rejection. That pushes a tree that the checks never ran on, or drops the other commits.

After a push that moved `origin/<head>`, read the ci check of the pushed commit (see **Checks**). Report it in the PASS line. The run is over, so the loop does not trace a failure there. A STOP that pushed does not meet the goal when its ci shows a failed suite check or `no checks` (see the goal text).

The next turn sets up a new run: that setup traces the failure, or stops on the head with no checks. A pass that neither sets up the run nor pushes reports ci as n/a. A STOP with no commit to push is the exception: the ci read of setup stands.

On every STOP, add the new REFUTED and DECISION rows to the PR's memory entry, if it has one, after the ci read when the STOP pushed. Report the DEFERRED, DECISION and CONFLICT rows.

## PASS line

The goal's evaluator reads only the transcript, so end every turn with the line below. Append it to the ledger too: the next pass reads the pass count and each pass's state there, and a pass without findings leaves no row. A STOP for convergence quotes the previous pass's PASS line from the ledger just above its own, since compaction can drop that turn from the transcript the evaluator reads.

```text
PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason>
```
