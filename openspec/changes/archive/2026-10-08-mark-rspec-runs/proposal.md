# Mark each run of the Camaleon suite and name the runs that overlapped it

## Why

Two runs of the Camaleon suite in one checkout share the SQLite test database and the files of the
dummy app (`docs/ai/testing.md`). A failure in a run beside another run can come from that run.
The review-loop skill samples the processes with `pgrep` when its run starts and ends. A run that
starts and ends between the two samples stays unseen.

## What Changes

- Each run of the Camaleon suite leaves a run marker, an empty file
  `tmp/rspec-runs/rspec-<pid>-<start>.pid` under the repo root (`spec/support/run_marker.rb`). The
  run holds a lock on it while it is active.
- At exit, the run prints one line on stderr that names the run markers of the other runs that were
  active during it.
- A run marker error prints a warning and does not change the exit status of the run.
- Each run removes the run markers of the ended runs when no run is active.
- `docs/ai/run-markers.md` tells how to read the line and the warnings. `docs/ai/testing.md` points
  to it.

## Capabilities

### New Capabilities

- `rspec-run-markers`: the run marker of a run, the line at exit, the warnings and the removal of
  old run markers.

### Modified Capabilities

None.

## Impact

- `spec/support/run_marker.rb` and `spec/rspec_run_marker_spec.rb`.
- `docs/ai/run-markers.md`, `docs/ai/testing.md` and `CHANGELOG.md`.
- Development only. A plugin or host app suite leaves no run marker, because it does not load
  `spec/support` of Camaleon.
