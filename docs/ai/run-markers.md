# Run markers

Each run of the Camaleon suite leaves a run marker, an empty file `tmp/rspec-runs/rspec-<pid>-<start>.pid` under the repo root (`spec/support/run_marker.rb`). `<start>` is the time when the support files load, in Unix seconds. While the run is active, its process holds a lock on its run marker. The system releases the lock when the process and its forked children end, also after `kill -9`.

## The line at exit

At exit, a run prints one line on stderr when other runs of the Camaleon suite were active during it. For example:

```text
RspecRunMarker: other runs during this run: rspec-4182-1791450000.pid rspec-4190-1791450032.pid
```

The line names the run marker of each run that was active when this run loaded its support files, or that started later. Runs share the files of the dummy app (`docs/ai/testing.md`), so a failure in a run with this line can come from another run. Repeat the run with the same files and the same `--seed` when no other run is active.

The line comes after the summary of RSpec. A log of stdout alone does not contain the line, so put `2>&1` after the redirect of stdout: `bin/rspec > <log> 2>&1`.

The line names a run only when that run wrote a run marker. The line cannot show these runs:

- A run of a plugin or host app suite, also when it uses this checkout through `CAMALEON_CMS_PATH`. A plugin or host app suite does not load `spec/support` of Camaleon.
- A run that stops before the support files load.
- A run that cannot write its run marker.
- A run that was active at the load of this run and whose run marker this run cannot open. An example is a run marker of another OS user with mode 0600. This run counts that run as ended.
- A run whose run marker directory was removed while it ran, for example by `rm -rf tmp`. The next run creates the directory again and never finds that run.

A process that is not a run of the suite leaves no run marker either, for example `bundle exec rake app:db:test:prepare`, which rewrites the shared test database.

`rspec --bisect` runs each round in a fork of one run, so it is one run. With `config.bisect_runner = :shell`, each round is a run of its own. The process of `rspec --bisect` holds a run marker too, and it names every round at exit.

## Warnings

A run prints these warnings on stderr and continues. After a `no run marker` or `cannot list` warning, treat the run as if another run was active.

- `RspecRunMarker: no run marker for this run: <error>`, and `RspecRunMarker: no run marker for this run` again at exit. The run cannot see the other runs, and the other runs cannot see it.
- `RspecRunMarker: cannot list the run markers at exit: <error>`. The run does not print the line at exit.
- `RspecRunMarker: cannot remove an old run marker: <error>`. A run removes the run markers of the ended runs when no run is active. The run keeps that old run marker, and the line at exit is still complete. This warning needs no action.
