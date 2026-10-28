# Resume of a cut-off pass

A cut-off pass (`procedure.md`, Pass start) finishes instead of a new pass. `procedure.md`, Checks, defines a batch and an open `fix` line. A `task` line after the previous PASS line names a task of the cut-off pass. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"). A `task` line of a ci poll is over when a `ci` line follows it. The state of the checkout and the lines after that PASS line tell the two kinds of open work apart:

- **A clean tree after that PASS line:** with a `review` line, fix the open `todo` lines. Run no new review, except the rework review that `procedure.md` Pass runs in a resumed pass. Before a fix, read the candidate block of this pass with the claim of the `todo` line, if any. A `todo` line is open until the rows with its claim after it name every location that it names. Without a `review` line, read the candidate files of this pass (`procedure.md`, Pass) and run the review. An angle whose file ends with `done` does not run again, and a candidate with its votes in a verifier file needs no new verifier.
- **A dirty tree with the `<tree>` of the last `fix` line after that PASS line:** the run's own, left during the checks of that fix. The `write-tree` command of the checkout test (`procedure.md`, Checks) prints the `<tree>` of the checkout. Finish the checks and the commit as below.

Look for the last spec-run `task` line after the first `fix` line of the last `<tree>`. With none, run the lint first (below), then start the spec run, unless no spec file applies (`spec-runs.md`). Another such line between them is a first run that failed or had no result: judge both (`docs/ai/failures.md`, `spec-runs.md`). A `task` line marked `# no fix`, or whose command runs in the clone of `docs/ai/failures.md` step 1, is neither run. A `fix` line of category `ci` resumes at the run after the fix (`trace.md`), which says whether the commit also runs its specs.

Then run the lint of `AGENTS.md`, unless `procedure.md` Checks makes it n/a. That lint run appends no `fix` line when the tree is still the `<tree>` of the last `fix` line. The lint can fail at that tree: the batch before a failure fix (`procedure.md`, Checks) comes after the failed check, which can be the lint. After the spec run that the commit needs, run the other checks (`procedure.md`, Checks).

Without an open line that ends with a SHA, the open lines get one commit (below) and no fixup commit. Otherwise such a line names a failure fix, which gets a fixup commit first (`spec-runs.md`). Its hunks are the difference between an earlier tree and the tree of the last batch. The earlier tree is HEAD when every open line ends with a SHA. Else it is the tree of the open batch before the last one (`procedure.md`, Checks). Stop the run and report the open lines when the two trees do not tell the hunks apart:

- Two open lines end with different SHAs.
- The earlier tree is that of an open batch, and a line of that batch ends with a SHA.
- The earlier tree is not HEAD, and no open batch comes before the last one.

Otherwise run the fixup command of `docs/ai/workflows.md` Phase 3 in the checkout, once the checkout test holds. In it, `<before>` is the earlier tree, `<after>` the tree of the last batch, and `<sha>` the SHA of the open lines. Join to it, with `&&`, a FIXED row for each open line that ends with `<sha>` (`procedure.md`, Ledger rows). When the apply exits with 1, the two fixes are related (Phase 3). Then skip the fixup commit: every open line goes in the commit below. When the apply exits with a code above 1, or another command fails, stop the run and report the output.

Then commit the lines that are still open, if any, after `git -C <checkout> add -A`, with their rows. The fix SHA of those rows is the SHA of that commit. The row of a failure fix of an earlier commit also names that commit (`spec-runs.md`).

A cut-off pass 1 finishes the same way against the `setup HEAD` under the last run header, without a new setup. It also reads the ci check of setup again from the start (`setup.md`, CI). The pass commits the lines that are still open before it traces a failed job. The pass traces a failed job only when this run has no FIXED row of category `ci` for that job.

In the ledger as found, a `rerun` line of this run with no later `ci` line of this run leaves a trace open. Its job is the failed job of the last `ci` line of this run before it, and without one only the ci read applies. Read that job with `--attempt <n>`, the attempt on the `rerun` line, and judge the rerun as `trace.md` says.
