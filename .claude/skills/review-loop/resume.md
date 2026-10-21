# Resume of a cut-off pass

A cut-off pass (`procedure.md`, Pass start) follows this file: it finishes instead of a new pass. A batch and an open `fix` line are defined in `procedure.md`, Checks.

The open work of a cut-off pass has three kinds. The state of the checkout and the lines after the previous PASS line tell them apart. A `task` line after that PASS line names a task of the cut-off pass. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"), instead of a new run. A `task` line of a ci poll is over when a `ci` line follows it.

- **Commits past the `<before>`, with ledger rows that record their SHAs:** the run's own. A pass cut off before its PASS line left them: finish that pass instead of a new one.
- **A clean tree, with a `review` line after that PASS line:** the pass fixes the open `todo` lines and runs no new review. A `todo` line is open until the rows with its claim after it name every location that it names. With no `review` line after that PASS line, the pass runs its review. It first reads the candidate files of this pass (`procedure.md`, Pass). An angle whose file ends with `done` does not run again, and the other angles do.
- **A dirty tree with the `<tree>` of the last `fix` line after that PASS line:** the run's own. A pass cut off during the checks of that fix left it. The temporary-index command of the checkout test (`procedure.md`, Checks) prints the `<tree>` of the checkout. Finish the checks and the commit as below.

For the dirty-tree kind, look for the last `task` line of a spec run after the last `fix` line. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"). With none, run the lint first (below), then start the spec run, unless the commit has no spec file (`spec-runs.md`). Another such line between them is a first run that failed or had no result: judge both (`docs/ai/failures.md`, `spec-runs.md`). A `task` line marked `# no fix`, or whose command runs in the clone of `docs/ai/failures.md` step 1, is neither the first nor the second run. A `fix` line of category `ci` resumes at the run after the fix (`trace.md`), which says whether the commit also runs its specs.

Then run the lint of `AGENTS.md`, unless `procedure.md` Checks makes it n/a. The batch of the append before a failure fix (`procedure.md`, Checks) can come while the lint fails. Then run the checks after the spec run that the commit needs: brakeman, zeitwerk:check and the openspec commands (`AGENTS.md`).

An open line whose last field is a SHA names a failure fix. Without one, skip the fixup commit and its stop cases: the open lines get one commit (below). A failure fix gets a fixup commit first (`spec-runs.md`). Its hunks are the difference between an earlier tree and the tree of the last batch. When every open line ends with a SHA, the earlier tree is HEAD. Otherwise it is the tree of the open batch before the last one, appended before the failure fix (`procedure.md`, Checks).

Stop the run and report the open lines when the two trees do not tell the hunks apart:

- Two open lines end with different SHAs.
- The earlier tree is that of an open batch, and a line of that batch ends with a SHA. A repair, a re-append or a second failure fix followed the first.
- The earlier tree is not HEAD, and no open batch comes before the last one.

Otherwise make the fixup commit first, alone, from a temporary index: the files of the checkout stay as they are. Before the chain, the checkout test (`procedure.md`, Checks) must hold.

The chain is the fixup command of `docs/ai/workflows.md` Phase 3, run in the checkout. In the command, `<before>` is the earlier tree, `<after>` the tree of the last batch, and `<sha>` the SHA of the open lines. Join to the chain, with `&&`, a FIXED row for each open line that ends with `<sha>` (`procedure.md`, Ledger rows). When the apply exits with 1, the two fixes are related (Phase 3). Then skip the fixup commit: every open line goes in the commit below. When the apply exits with a code above 1, or another command fails, stop the run and report the output.

Then commit the lines that are still open, if any, after `git add -A`, with their rows. Write the fix SHA, the SHA of the commit, in the evidence field of each of those rows. The row of a failure fix also names the commit that it fixes (`spec-runs.md`).

A pass 1 can be cut off that way: its run header is the last of the ledger, with no PASS line under it. Finish it the same way against the `setup HEAD` under that header, without a new setup. In pass 1, the `setup HEAD` line takes the place of the PASS line.

The `ci` lines of the `setup HEAD` under that header say where setup was cut off:

- No such line: read the ci check of setup first. When a poll ran, its last `task` line names its log.
- The last such line names a failed job, with no `fix` line of category `ci` after it: the trace is still open. Read the ci check again, then finish the trace.
- A `rerun` line with no `ci` line after it: read the ci check again. `ci.md` says when that line counts as a rerun.
- The last such line says `no jobs`, `pending` or `cancelled`: the pass stops at its end. Finish it, then write its PASS line with the stop.
