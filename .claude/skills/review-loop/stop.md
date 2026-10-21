# The push of a stop

A stop that pushes (`procedure.md`, Pass states and stop) follows this file. The STOP push carries every commit of the run. Decide the skip marker for the whole push: GitHub reads it off the last commit alone (`docs/ai/workflows.md` Phase 3). A marked docs-only last commit also skips CI for the code commits of the run. The checks ran before each commit of the run, so the push needs no other check run (`AGENTS.md` "Verify before pushing").

The steps, in this order:

1. Fetch `origin/<head>`, and read the `state` of the PR again. A merged or closed PR stays unpushed and unfolded: say so, and skip the other steps.
2. When `origin/<head>` holds HEAD (`git -C <checkout> merge-base --is-ancestor HEAD origin/<head>` exits with 0), skip the push and compare HEAD with the `setup HEAD`:
   - HEAD is the `setup HEAD`: the run made no commit. Skip the other steps.
   - HEAD is past the `setup HEAD`: a pass cut off after its push made the commits. Continue with step 4.
3. Push with `git -C <checkout> push origin <head>`, and once more when it fails without a rejection. When git rejects the push, or the second push fails, the stop stays unpushed and unfolded. Say so, and skip the other steps. Do not pull, rebase or force past a rejection. After a pull or a rebase, the push carries a tree that the checks never ran on. A forced push drops the other commits.
4. Start the ci read of HEAD (`ci.md`). A poll, when `ci.md` starts one, runs as a background task, and the fold runs meanwhile.
5. Fold the PR description (`docs/ai/workflows.md` Phase 4). Save the live description with `gh pr view <pr> --repo <project> --json body --template '{{.body}}' > tmp/review-loop/<repo>/<pr>.live.md`, and copy it to `tmp/review-loop/<repo>/<pr>.fold.md`. Fold the run into `tmp/review-loop/<repo>/<pr>.fold.md`. Run the Markdown gate (`procedure.md`, Ledger rows) with the input `diff -U0 --strip-trailing-cr tmp/review-loop/<repo>/<pr>.live.md tmp/review-loop/<repo>/<pr>.fold.md`: a description edited on GitHub can have CRLF line ends. Then run `gh pr edit <pr> --repo <project> --body-file tmp/review-loop/<repo>/<pr>.fold.md`.
6. End the ci read: wait for the poll, if any (`docs/ai/testing.md` "Long commands"), and read its result as `ci.md` says. The run is over, so the loop does not trace a failure there. It reruns once each run in which a suite job did not pass, as `ci.md` says. A job that fails again is the failed job that ci reports. After a DECISION or CONFLICT stop, it reads ci and reruns nothing.

A STOP that pushed does not meet the goal when its ci is neither ok nor n/a (see the goal text). A DECISION or CONFLICT stop meets the goal whatever its ci: the user answers the rows first.
