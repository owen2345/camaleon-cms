# Review loop procedure

The procedure of a run of the review loop. The live `SKILL.md` of the skill gives the parameters and makes the copies of the rule files, and a run follows the copy of this file.

## Setup (first pass of a run)

- **Target:** resolve the checkout path as its real path (`git -C ../<repo> rev-parse --show-toplevel`) and its GitHub project (`gh repo view --json nameWithOwner --jq .nameWithOwner`, run in the checkout). In a fork checkout, as below, give that command the URL of `<remote>`. `gh` answers with `origin`, the fork, unless that remote is named `upstream` or `github`. Then read the PR: `gh pr view <pr> --repo <project> --json state,headRefName,baseRefName,headRefOid,headRepositoryOwner,headRepository` gives its state, its head and base branches, its head commit and its head repository. Then fetch both branches: `git -C <checkout> fetch origin <head> <base>`. In a fork checkout, only `<head>` comes from `origin`.

  The run goes on only when each condition below holds. Otherwise stop and say so in a `PASS 0/8` line. Do not switch, pull, stash or commit.
  - The PR is open.
  - The head of the PR is in the repository of `origin`: the `headRepositoryOwner` login and the `headRepository` name, as `<owner>/<name>`, equal `gh repo view <origin's URL> --json nameWithOwner --jq .nameWithOwner`. A PR from another fork fails this, because the STOP push goes to `origin`.
  - `origin/<head>` is at the head commit of the PR.
  - The checkout is on the head branch, at `origin/<head>`: a commit that is not pushed is then a commit of the run.
  - The checkout is clean: `git -C <checkout> status --porcelain` prints nothing.
  - The tests of the checkout are RSpec specs, the only suite the checks run: `git -C <checkout> ls-files 'test/*_test.rb'` prints nothing. A plugin still on minitest stops here.
  - The checkout has `bin/rubocop` and `bin/rspec`, which the checks run.

  Every range below starts at `<base-ref>`: `origin/<base>`, never the local base branch, which can lag behind. In a fork checkout, `origin` is a fork and another remote, `<remote>`, is the project (`git -C <checkout> remote -v`, often `upstream`). The `<base>` of the fork can lag the same way. So `<base-ref>` is `<remote>/<base>`, fetched from it (`git -C <checkout> fetch <remote> <base>`). The head, the conditions above and the STOP push stay on `origin`.
- **Spec clone:** the spec runs of the loop run in a clone of the checkout, so that no other run shares their files. A host app is the exception (**Checks**). `<spec clone>` is `<scratchpad>/<repo>-clone`. The first sync of **Checks**, before a spec run or a trace, makes it when it is missing. A run with no spec run never makes it.
- **Commands** run against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`.
- **Ledger:** `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms, whatever the target repo, never committed. A ledger with no `## Run` header does not exist yet, or holds only the `PASS 0/8` line of a setup that stopped before this step. Only then create it, if needed. Seed it as pass 0 from the memory entry of the PR, if any. The seed holds the REFUTED and DECISION rows that every STOP adds there. It also holds any other refuted entry as REFUTED, and any skipped entry as DECISION, or as FIXED when a later commit fixed it.

  Each run appends, in one command, `## Run <date>, effort <level>` and the line `setup HEAD <sha>`, the PR head that setup found. It counts its passes from 1. The rows of earlier runs still count for the verdict checks.
- **Rules:** `SKILL.md` made the copies of the rule files in `tmp/review-loop/<repo>/<pr>.rules/`, and every pass loads the rules from there.
- **CI:** read the ci check of the `setup HEAD`, as **Checks** says. A poll, when **Checks** starts one, runs as a background task, which gives the ledger its `task` line, and the review goes on meanwhile. When the poll ends, read its result as **Checks** says. Append the `ci` line of **Checks** when the read ends, with the `setup HEAD` as its `<sha>`. The read ends before the trace of a failed job. With no failed job, it ends after the one rerun of a run, when that run gets one. Before its PASS line, pass 1 waits for a poll that still runs (the wait of `docs/ai/testing.md` "Long commands").

  The first `ci` line under the run header is the ci read of setup. Trace a failed suite job there (`trace.md`) in pass 1, before the review when possible, otherwise before the PASS line. The run stops on `no jobs`, `pending` or `cancelled` (**Checks**). The stop comes at the end of pass 1, which commits its fixes first.

Every pass starts with two steps, after `SKILL.md` loaded `procedure.md` from the copies of the run:

- It notes HEAD.
- It reads the ledger, but not every row of this run. Its PASS, `setup`, `ci` and `rerun` lines give the pass count and the state of each pass. The rows after its last PASS line, the `task` and `fix` lines among them, are the open work of a cut-off pass. The verdicts check the REFUTED, DECISION and CONFLICT rows of the whole ledger, the seed of pass 0 included. Step 5 checks the location of the FIXED rows of this run.

From pass 2 on, the pass also checks the checkout. The checkout must still be on the head branch, at the HEAD that the previous PASS line ends on. Its tree must be clean, or the run's own (below). Other sessions and the IDE share the checkout. Without this check, the pass reviews and commits a switch, an edit or a commit made between passes as the work of the run. The push can also carry such a change, under checks that ran on another tree.

Commits past the HEAD of the previous PASS line are the run's own when the ledger rows after that line record their SHAs. A pass cut off before its PASS line left them: finish that pass instead of a new one. A `task` line after that PASS line names a task of the cut-off pass. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"), instead of a new run.

A dirty tree is the run's own when the tree of the checkout is the `<sha>` of the last `fix` line after that PASS line. Compute that tree with a temporary index: `(export GIT_INDEX_FILE=<tmp>; git -C <checkout> read-tree HEAD && git -C <checkout> add -A && git -C <checkout> write-tree)`. `<tmp>` is an absolute path outside the checkout, and the index of the checkout stays as it is. The pass was cut off during the checks of that fix: finish it.

Look for the last `task` line of a spec run after the last `fix` line. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"). With none, start the spec run, unless the commit has no spec file (**Checks**). Another such line between them is a first run that failed, or had no result: judge both as `docs/ai/failures.md` and **Checks** say. A `task` line that ends with `no fix`, or whose command runs in the clone of `docs/ai/failures.md` step 1, is neither the first nor the second run.

Then run the checks after the spec run that the commit needs: brakeman, zeitwerk:check and the openspec commands (`AGENTS.md`). Then commit the fix with the rows that the `fix` lines of that `<sha>` hold. Write the SHA of the commit as their evidence.

A pass 1 can be cut off that way: its run header is the last of the ledger, with no PASS line under it. Finish it the same way against the `setup HEAD` under that header, without a new setup.

The lines under that header say where setup was cut off:

- No `ci` line: read the ci check of setup first. When a poll ran, its last `task` line names its log.
- The last `ci` line names a failed job, with no FIXED row of category `ci` after it: the trace is still open. Read the ci check again, then finish the trace.
- The last `ci` line says `no jobs`, `pending` or `cancelled`: the pass stops at its end. Finish it, then write its PASS line with the stop.

Any other state of the checkout stops the run: say so. Do not switch, reset, stash or commit. When the commits of the branch changed, also tell the user to start a new run. A rebase onto the base is one example. The user must push the branch before that run, because setup stops on a checkout that is not at `origin/<head>`. A rewrite of pushed commits needs the lease of `docs/ai/workflows.md` Phase 3.

## Pass

Run `/code-review <effort> --fix` on the local branch of the checkout against the base, unpushed commits included. Give it no target for camaleon-cms, and the checkout path for another repo. Its scope is `git -C <checkout> diff <base-ref>...HEAD`, whatever range `/code-review` picks on its own. On its own, it can pick `@{upstream}...HEAD`, which holds only the commits not yet pushed. Never target the PR number: that can review the pushed head, which lacks the commits of this run. When the review cannot cover that whole range, stop and say so.

For another repo, the conventions angle of the review holds the code to the `CLAUDE.md` of camaleon-cms (`AGENTS.md`). Plugin, theme and host app checkouts carry no agent docs of their own. A CLAUDE.md governs only the files at or below its directory, so the angle finds none otherwise. The "Gem, not an app" and "Support range" rules of `AGENTS.md` are the gem's, and they do not bind a host app. Its root `bin/rails` runs the app, which has no dummy, and the app runs the one Rails and Ruby version that it pins. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function, spec example or doc section heading (no line numbers) | category | verdict | evidence (fix SHA, or reason + the HEAD that it was judged at)

Append the rows other than FIXED when their findings get a verdict. Append a FIXED row in the same command as the commit of its fix, which gives the row its SHA.

The message of a commit follows `docs/ai/prose.md`: a subject line and at most three sentences, with no pass number and no ledger label. Before the commit, print each sentence of the message file over the bound, and reword it: `ruby -e 'bad = false; File.read(ARGV[0]).split(/(?<=[.!?])\s+(?=[^a-z])|\n\n+/).each { |s| n = s.split.size; next if n <= 25; bad = true; puts "#{n}: #{s}" }; exit(bad ? 1 : 0)' <file>`. The command counts each word of a code span, so a count of 25 or less meets the bound. It exits with 1 when it prints, so `&&` can chain the commit after it.

The commit of a failure fix (`docs/ai/workflows.md` Phase 3) also gets a FIXED row, with the check as its category. The category is `ci` for the fix of a failed suite job, and `flake` for a flake fix. A repair of a line, a spec example or a new file of the uncommitted fix (`docs/ai/failures.md`) is part of that fix. The repair gets no row of its own. Because each commit command appends its rows, a pass cut off before its PASS line leaves every commit that it made on record.

The loop never rewrites a commit. A rewrite gives commits new SHAs, which the rows and PASS lines no longer match. A failure that an earlier commit of the branch caused gets a `fixup!` commit (`docs/ai/workflows.md` Phase 3). The user folds the fixup commits with `git rebase --autosquash <sha>~1`, where `<sha>` is the oldest commit that they fix. The report names the fixup commits and `<sha>`.

## Verdicts

Check the steps in order. A finding that is also a correctness or security defect skips steps 5 and 6 and goes to step 7, whatever its category. The pass applies only FIXED and leaves no finding without a verdict. Commit the fixes as `docs/ai/workflows.md` Phase 3 says.

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED. Low severity or a loud failure is no reason to defer a confirmed defect.
2. Same claim as a DECISION or REFUTED row, on code that the row's HEAD also has → REPEAT if DECISION, CONFLICT if REFUTED. A REPEAT row names the new evidence of the finding, if any, for the user. The row's HEAD is the HEAD at which the pass judged it. A row that names no HEAD, such as a pass 0 seed, has the `setup HEAD` of the run header after it. If that code changed, treat the claim as new. A sentence that a commit of the run added, reworded, split or moved, and that keeps the decided meaning, counts as the same code.

   Also treat it as new when the repository no longer has that HEAD (`git -C <checkout> cat-file -e <sha>` fails). A rewrite leaves the old HEAD off the branch, but the repository keeps it.
3. A fix that undoes a commit already on this branch (`<base-ref>..HEAD`) gives CONFLICT. A fix that goes against a DECISION row on the same code, as step 2 defines it, gives CONFLICT too.
4. Needs a design trade-off or the user's call → DECISION. The `decision` parameter says whether the row stops the run after this pass (see **Pass states and stop**).
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED. A fix that preserves behavior needs no new spec, because the checks prove it. A fix that changes behavior, as a conventions fix can, gets its own spec. A coverage-only fix is the new spec.

   Once step 5 is frozen (see below), the findings of step 5 are DEFERRED instead. A cleanup is also DEFERRED when a cleanup of an earlier pass of this run reshaped that function, spec example or doc section.
6. Altitude or wording → FIXED in pass 1, DEFERRED after. Wording is text that still gives the right outcome when a reader follows it literally. Text that gives a wrong outcome is a defect.
7. A correctness or security defect → FIXED, with the spec that reproduces it. `AGENTS.md` "Specs" and `docs/ai/workflows.md` Phase 3 give the exceptions.

## Checks

The checks are the four in camaleon-cms `AGENTS.md` "Verify before pushing", in the form of the table for each kind of checkout. A check that `AGENTS.md` "Verify before pushing" exempts the branch or the commit from is also n/a.

| | camaleon-cms | plugin or theme | host app (PostgreSQL) |
|---|---|---|---|
| suite workflows | `Audit`, `Test supported versions` | `CI` | `test-on-push` |
| brakeman | `bin/brakeman --no-pager` | n/a | `bin/brakeman --no-pager` |
| zeitwerk:check | `(cd spec/dummy && bin/rails zeitwerk:check)` | the same | `bin/rails zeitwerk:check` |
| spec database | the SQLite file of the spec clone | the same | its own test database, shared with every checkout of the app |
| spec runs | the spec clone | the same | the checkout, under the other-run wait |

The loop runs the checks before each commit, the lint first, as `docs/ai/workflows.md` Phase 3 says. The PASS line reports the last run of each check in the pass, or n/a when the pass did not run it.

Every spec run, every ci poll and any other command that can outlast the timeout is a background task (`docs/ai/testing.md` "Long commands"). When the tool answers, append `task <id> <log> <command>` to the ledger.

Between the lint and the other checks of a fix, append one line `fix <sha> | <claim> | <location> | <category>` per FIXED row of its commit. A fix that runs no lint gets the lines at once. The last three fields are the claim, the location and the category of the row, for the resume of a cut-off pass (**Setup**). `<sha>` comes from `git -C <checkout> add -A && git -C <checkout> write-tree`: the tree of the checkout with the uncommitted fix. The `add` stages the fix, which its commit needs. After a repair of the fix, append its `fix` lines again with the new `<sha>`, before its checks.

Judge the command by its result, as `docs/ai/testing.md` "Long commands" says. With no result, start the command again once. A second spec run that ends with the same summary line and exit code is a failure: `docs/ai/failures.md` traces it. A hang, or any other second start with no result, stops the run: report the command with its log. A sync or a `gh` command that fails has no result too, and the report gives its output in place of a log.


The fifth check is **ci**: the GitHub workflow runs of a commit, the rows of `gh run list --commit <sha>`. In camaleon-cms, they test the PR merged into the base, on every Ruby and Rails of the matrix. Setup reads them for the `setup HEAD`. A stop that pushes reads them again for the pushed commit (see **Pass states and stop**).

Each read ends with the line `ci <sha> <ok, n/a, no jobs, pending, cancelled or the failed job>` in the ledger. Its `<sha>` is the HEAD that the read stands for: the `setup HEAD` at setup, and the pushed commit after a push. The ci field of a PASS line is the value of the last `ci` line of the run for the HEAD of the line. With no such line, it is n/a.

- The suite runs are the runs of the suite workflows of the table, which run the lint, the scans and the suite of the repo. Their jobs are the suite jobs. Every other run is advisory. Examples are `Test upcoming versions` (Rails edge and Ruby head) and `Test ecosystem members`. A failed or cancelled advisory run gets a DECISION row, and a pending one gets no row. No advisory run fails ci, but a failed suite job does.
- In the commands below, `S` holds the suite workflows of the table, joined with `|`. The commands show the camaleon-cms value.
- ci is n/a when the repo has no workflow file. After a push, ci is n/a when the pushed head carries a skip marker. Then do not read ci. `docs/ai/workflows.md` Phase 3 lists the markers, and `git -C <checkout> log -1 --format=%B <sha>` shows the message. Match a bracket marker anywhere as a fixed string (`grep -F '<marker>'`). A `skip-checks` trailer counts only when `git -C <checkout> cat-file commit <sha> | tail -n 3` prints two empty lines and then the trailer.
- `<sha>` is the full SHA of the head: `gh` matches no short SHA and prints an empty list for one. At setup, a marked head has no suite run of its own. The `<sha>` of the commands is then the head of the newest suite run of the branch, and the `ci` line keeps the `setup HEAD`: `S='Audit|Test supported versions' gh run list --repo <project> --branch <head> --limit 100 --json headSha,workflowName --jq '[.[] | select(.workflowName | test("^(" + env.S + ")$"))] | .[0].headSha // empty'`. The command prints nothing when the branch has no suite run (ci n/a), and a failed `gh` is no result. After a rebase, that run can be on a commit that the branch no longer has: when `git -C <checkout> merge-base --is-ancestor <sha> HEAD` fails, ci is n/a too.
- At setup, list the runs once: `gh run list --repo <project> --commit <sha> --json workflowName,status,conclusion,databaseId`. When every suite workflow has a run, and every suite run is completed, read the conclusions of the runs (below). Else, and after a push, read ci with one poll, as a background task: `for i in $(seq 120); do r=$(S='Audit|Test supported versions' gh run list --repo <project> --commit <sha> --json workflowName,status --jq '[.[] | select(.workflowName | test("^(" + env.S + ")$"))] | if (unique_by(.workflowName) | length) < (env.S | split("|") | length) then "absent" elif all(.status == "completed") then "completed" else "pending" end'); echo "$i $r"; case "$r" in completed) exit 0;; absent) [ "$i" -ge 11 ] && exit 3; e=0;; pending) e=0;; *) e=$((e+1)); [ "$e" -ge 3 ] && exit 5;; esac; sleep 30; done; exit 4`.
- The exit code of the poll is its result:
  - 0: every suite run is completed.
  - 3: a suite workflow still has no run after five minutes. GitHub makes the runs seconds after a push, so it made no run of that workflow for the head. A merge conflict of the PR with the base is one cause, and a workflow file that does not parse is another. Report ci as `no jobs`.
  - 4: a suite run is still pending after an hour. Report ci as `pending`.
  - 5: three calls of `gh` one after the other failed, and the log holds the error. The poll has no result.
- After exit code 0, list the runs again and read the conclusions (below).
- Of the runs of one suite workflow, read the newest, with the largest `databaseId`. A reopened PR gives a workflow a second run on the same head. A conclusion `success` or `skipped` passes. For any other conclusion of a suite run, `gh run view <run id> --repo <project> --json jobs --jq '.jobs[] | select(.conclusion != "success" and .conclusion != "skipped") | "\(.databaseId) \(.conclusion) \([.steps[] | select(.conclusion == "failure")] | length) \(.name)"'` names the jobs that did not pass, with the count of their failed steps.
- A job with a failed step is a failed job. At setup, read the copy of `trace.md` of the run, and trace it as it says. Any other job that did not pass did not run to its end. Examples are a cancelled job, a job with no step, a job that timed out, and a suite run with no job. A job or a run that did not run to its end gets the one rerun of its run (below).
- Rerun a run once: append `rerun <run id>` to the ledger, then run `gh run rerun <run id> --repo <project> --failed`, which reruns the failed and the cancelled jobs. When GitHub refuses that command, run `gh run rerun <run id> --repo <project>`, the whole run. A workflow run with a `rerun` line anywhere in the ledger gets no second rerun, also from a later run of the loop. Then read ci again.
- At setup, trace a failed job of the run before its rerun, which the trace can start. A rerun tests the old commit, so a job whose failure the trace fixed fails again there. Its result does not count: a rerun whose other jobs pass gives ci ok. A job of the rerun that does not run to its end, or a refused whole-run rerun, gives ci `cancelled`: report the run.

- A spec run before a commit runs the specs of the fix and the adjacent specs (`docs/ai/workflows.md` Phase 3), never the whole suite. The exceptions are the trace of a CI failure (above) and an adjacent set above half of the suite (`AGENTS.md` "Verify before pushing"). `docs/ai/testing.md` says which files `bin/rspec` gets. When a commit has no such spec file, skip the run and report rspec as n/a.
- A commit that touches `openspec/` also runs the `openspec validate` commands of `AGENTS.md` "Verify before pushing".
- When a check fails, find out what caused the failure as `docs/ai/failures.md` says. Then fix it as `docs/ai/workflows.md` Phase 3 says. In the `git merge-base` command of `docs/ai/failures.md` step 4, `<base-ref>` takes the place of `origin/<base>`. For a spec run, the spec clone takes the place of the checkout, except for a host app (below). The failed run, the second run and the run after a fix happen there. The ignored file that its step 3 names is then a file of the spec clone.
- The clone of `docs/ai/failures.md` step 1 stays a clone of its own, outside the spec clone. The run of step 2 without the fix comes first, in the spec clone synced without the `git diff … | git apply` part of the sync. Its `task` line ends with `no fix`. Make the clone of step 1 only when that run fails.
- `docs/ai/failures.md` step 4 runs the check at the start commit of the branch. When it fails there in the same way, stop the run. Leave the uncommitted fix in the tree, and name it in the report as the run's own.
- When a commit of the branch caused the failure, make the fixup commit of `docs/ai/workflows.md` Phase 3, without the rebase. The FIXED row of the fixup commit also names the commit that it fixes. The pass stops the run after its last commit (see **Pass states and stop**).
- A spec run of the loop, before a commit or in a trace, runs in the spec clone (see **Setup**), never in the checkout. Before the spec run, sync the spec clone, with the ten-minute timeout (an install can take minutes): `[ -d <spec clone> ] || git clone -q <checkout> <spec clone>; git -C <spec clone> fetch -q <checkout> HEAD && git -C <spec clone> reset -q --hard FETCH_HEAD && git -C <spec clone> clean -fdq -e 'gemfiles/*.lock' && git -C <checkout> add -A && git -C <checkout> diff HEAD --binary | git -C <spec clone> apply --allow-empty && (cd <spec clone> && bundle install --quiet)`. The sync brings the spec clone to the tree of the checkout, copies the uncommitted changes with their new files, and installs the gems. The reset discards the changes that the previous spec run copied in. The `clean` keeps the lock of a job gemfile for a trace (`trace.md`). A failed sync has no result (above).
- The spec clone keeps its caches: `git clean` without `-x` leaves the ignored files. No other spec run shares the files of the spec clone or its SQLite file, so a failed spec run there counts. A subagent that runs specs makes a clone of its own the same way, at another path.
- A host app on PostgreSQL (camaleon_website, florsan) runs its specs in the checkout, with no spec clone. A clone lacks the ignored files that its boot reads, such as `.env` and `config/master.key`, and its test database is shared with every checkout anyway. There, a spec run starts only when no other spec run is active. The wait for other runs of `docs/ai/testing.md` "Which specs to run" checks that, an hour at most. A spec run still active after the hour stops the run, and the report names its pids. A failed spec run there does not count when `pgrep -f '[r]spec'` names another run at its end: run it again alone, as Phase 3 says.
## Pass states and stop

- **SETTLED:** the pass ran to the end and applied no correctness or security fix. Every check passed or was n/a, and the checkout's tree is clean. A correctness fix is a FIXED row whose category is correctness, security, flake or a check name. Step 5 and step 6 fixes can go in.
- **CLEAN:** SETTLED, and applied nothing at all (HEAD unchanged).
- **UNSETTLED:** anything else.

Step 5 freezes after the first SETTLED pass of the run, and in pass 8: from then on, its findings are DEFERRED. A converged run therefore ends on a pass that applied nothing, and every change it made was reviewed by a later pass.

Stop and push in these cases:

- The latest pass is CLEAN and the run's pass before it SETTLED or CLEAN (converged).
- Pass 8 did not converge. Report it as not converged.
- A second CONFLICT on the same claim. Show both sides.
- A review cannot cover its range.
- A DECISION row in this pass that the `decision` parameter names (`SKILL.md`, Parameters). The pass applies its other verdicts and commits first. The user answers the rows before the next run, and each answer goes in as a commit, pushed before that run.

These stops push nothing, also when a reason to push applies, and so does any stop that neither list names. Each is defined where it happens:

- A setup stop, also on a ci read of setup with `no jobs`, `pending` or `cancelled` (**Setup**).
- A checkout that changed between passes (**Setup**), or a pass that ends with uncommitted changes, which can be another writer's.
- A diff that undoes an earlier commit of the branch, or a `fixup!` commit (**Ledger rows**).
- A check that fails with no fix, or a failure that was there before the branch (**Checks**).
- A CI failure that the spec clone does not show and that a rerun shows again (`trace.md`).
- A hang, or a command with no result twice (**Checks**).
- The wait of a host app that ends after its hour (**Checks**).

`AGENTS.md` wants the checks before a push, and the user judges an undo, another writer's change or a fold. A stop without a push leaves the commits of the run for the user to push before the next run (see **Setup**).

Commit but do not push during the run. The STOP push carries every commit of the run. GitHub reads the skip marker off the last commit of the push alone, so decide the marker for the whole push (`docs/ai/workflows.md` Phase 3). A marked docs-only last commit also skips CI for the code commits of the run. At a stop that pushes, push the head branch once and fold the PR body (`gh pr edit <pr> --repo <project>`, per `docs/ai/workflows.md`).

The checks ran before each commit of the run, so the push needs no other check run (`AGENTS.md` "Verify before pushing").

Before the push, fetch `origin/<head>`. When it is at HEAD, skip the push. The run made no commit, or a pass cut off after its push made them. In the second case, read ci for HEAD, as below.

Push with `git -C <checkout> push origin <head>`.

A push rejected because `origin/<head>` moved during the run stays unpushed too. So does a PR merged or closed during the run: check its `state` again before the push. Leave the PR body unfolded and say so. Do not pull, rebase or force past the rejection. That pushes a tree that the checks never ran on, or drops the other commits.

After a push that moved `origin/<head>`, read the ci check of the pushed commit (see **Checks**). The run is over, so the loop does not trace a failure there. It reruns once each run in which a suite job did not pass, and reads ci again (**Checks**). A job that fails again is the failed job that ci reports. After a DECISION stop, it reads ci and reruns nothing: the trace at the setup of the next run starts the one rerun.

A STOP that pushed does not meet the goal when its ci is neither ok nor n/a (see the goal text). A DECISION stop is the exception, and counts as it stands. The user answers the rows first, and the setup of the next run traces the failure.

The next turn sets up a new run. After a DECISION stop, the turn after the answers sets it up. The setup of that run traces a failed suite job of the head, or stops as **Setup** says.

On every STOP, add the new REFUTED and DECISION rows to the PR's memory entry, if it has one. A STOP that pushed does this after its ci read. Report the DEFERRED, DECISION, REPEAT and CONFLICT rows.

## PASS line

The goal's evaluator reads only the transcript, so end every turn with the line below. Append it to the ledger too: the next pass reads the pass count and each pass's state there, and a pass without findings leaves no row. The `fixed` field counts the FIXED rows of the pass by category (**Pass states and stop**). The goal reads the STOP field: `pushed` when the run made a commit and `origin/<head>` is at HEAD after the stop, and `not pushed` otherwise. A STOP for convergence quotes the previous pass's PASS line from the ledger just above its own, since compaction can drop that turn from the transcript the evaluator reads.

```text
PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a, no jobs, pending, cancelled or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason, pushed or not pushed>
```
