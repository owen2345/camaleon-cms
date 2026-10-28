# The push of a stop

A stop that pushes (`procedure.md`, Pass states and stop) follows this file. The STOP push carries every commit of the run, each checked before its commit, so the push needs no other check run (`AGENTS.md`). The steps, in this order:

1. Fetch `origin/<head>`, and read the `state` of the PR again. A merged or closed PR stays unpushed and unfolded: say so, and skip the other steps.
2. When `origin/<head>` holds HEAD (`git -C <checkout> merge-base --is-ancestor HEAD origin/<head>` exits with 0), skip the push. HEAD at the `setup HEAD` means no commit: skip the other steps. HEAD past it means a pass cut off after its push: continue with step 4.
3. Push with `git -C <checkout> push origin <head>`, and once more when it fails without a rejection. A rejection, or a second failure, leaves the stop unpushed and unfolded: say so, and skip the other steps. Do not pull, rebase or force past a rejection.
4. Start the ci read of HEAD (`ci.md`), with a poll as a background task while the fold runs.
5. Fold the PR description (`docs/ai/workflows.md` Phase 4). Save the live description with `gh pr view <pr> --repo <project> --json body --template '{{.body}}' > tmp/review-loop/<repo>/<pr>.live.md`, copy it to `tmp/review-loop/<repo>/<pr>.fold.md`, and fold the run into the copy. Run the Markdown gate (`docs/ai/prose.md`) on `diff -U0 --strip-trailing-cr tmp/review-loop/<repo>/<pr>.live.md tmp/review-loop/<repo>/<pr>.fold.md`. Then run `gh pr edit <pr> --repo <project> --body-file tmp/review-loop/<repo>/<pr>.fold.md`.
6. End the ci read: wait for the poll, if any (`docs/ai/testing.md` "Long commands"), and read its result as `ci.md` says. The run is over, so the loop traces no failure there. A suite job that did not pass gets the one rerun of `ci.md`. A job that fails again is the failed job that ci reports. A job that passes the rerun was a flake: name it in the report. After a DECISION or CONFLICT stop, read ci and rerun nothing.

A STOP that pushed meets the goal only when its ci is ok or n/a (see the goal text). A DECISION or CONFLICT stop meets it whatever its ci: the user answers the rows first.
