# Design

## Context

See proposal.md, "Why". The support file loads with the other files of `spec/support`, before the
suite touches the shared database and the shared files of the dummy app. It runs in the process of
the suite with no gem of its own.

## Goals / Non-Goals

**Goals:**

- A run learns at exit which other runs of the Camaleon suite were active during it.
- A run that another process kills still counts as ended, and a run that is stopped still counts
  as active.
- A file system error of the tool never fails the suite or changes its exit status.

**Non-Goals:**

- A run marker for a plugin or host app suite.
- A command that lists the active runs. The review-loop skill keeps its `pgrep` check before it
  starts a run.
- A change of the shared database or the shared files, which cause the failures that the line
  explains.
- A lock that refuses or delays a second run. A round of `rspec --bisect` with
  `config.bisect_runner = :shell` runs beside its parent run, and the IDE or another session can
  start a run by mistake. The tool cannot tell the two apart, and a run that stops in a debugger
  keeps such a lock for days. The line reports an overlap and does not prevent it.

## Decisions

The maintainer chose D1, D4, D5, D9, D10, D11 and D12 on 2026-10-08, and the current form of D4 and
D10 on 2026-10-09. The first review-loop run added D7 and raised D6, which the maintainer kept. The
third review-loop run added D2, D3 and D8.

**D1. The lock of the process is the test for an active run.** The run holds `flock(LOCK_EX)` on its
run marker for the life of its process, and a probe takes `LOCK_SH | LOCK_NB`. The system releases
the lock when the process and its forked children end, also after `kill -9`. Rejected:

- A rule of start and end times with a pid check through `ps`. It missed a run killed during the run
  of a session, and on Linux a clock change moves the process start that `ps` prints.
- A touch of the modify time at exit. A killed run never touches its run marker.

**D2. The run locks the file before the file gets its name.** The run creates
`rspec-<pid>-<start>.pid.tmp` with `File::EXCL`, locks it, links it to the name of the run marker
and unlinks the temporary name. The lock stays with the file through the link. Between an open under
the final name and the lock, another run found the run marker unlocked and never named this run.

Two runs in two PID namespaces on one checkout can have the same pid and the same start second. The
second run then finds the temporary file or the run marker of the first run, warns and continues
without a run marker. Rejected:

- A shared temporary file. It blocked the second run in `flock`.
- A rename of the temporary file. It replaced the run marker of the first run.
- A lock on the directory around the load step. It blocks every run while another process holds it,
  also a process stopped in a debugger.
- The same lock with a `LOCK_NB` bound, held only while `write` runs. It needs no hard links and
  leaves no temporary file after a kill. When the wait ends, the run must continue without the lock,
  which reopens the window, or without a run marker.

**D3. A failed list of the run markers raises.** `Dir.children` raises when the directory is gone or
unreadable, and `Dir.glob` returned an empty list. With the glob, a run whose `tmp/rspec-runs` was
removed printed an incomplete line with no warning. The list skips a name that is not valid in its
encoding, because the match raises on such a name.

**D4. A run marker of an ended run stays while any run is active.** The longer run must still name
at exit a run that started and ended during it. So an ended run keeps its run marker, and the run
removes the run markers of ended runs only when no run is active. The removal then uses locks and
never the clock, as D1 does. Rejected:

- A one-day age from the start in the name (the first design). A run that ended inside a run active
  for more than a day lost its run marker to the next load. The line of the longer run then missed
  it. An example of such a long run is one stopped in a debugger over a weekend.
- The start in the name against the start of the oldest active run (the second design). A clock
  step back put an ended run before an active run that it started inside. Two loads that straddle
  a second inside the write window did the same. The next load then removed its run marker.
- A record of the overlap in the run markers of the active runs (the third design). At load, a run
  appends its name to the run marker of each active run it finds, and at exit it reads its own. The
  run markers of ended runs could then go at once. A run marker of another user with mode 0600
  refuses the append, so the overlap is lost with no warning, and a run marker is no longer an
  empty file.

**D5. A run marker error prints a warning and the run continues (intended).** A file system error
of this tool must not fail the suite. The warning `no run marker for this run` prints at load and again at exit.
A reader of the end of the log then sees it. The warning `cannot list the run markers at exit`
replaces the line. The warning `cannot remove an old run marker` keeps the old run marker.

**D6. A run of `rspec --dry-run` also leaves a run marker (intended).** Its load of `rails_helper`
can change the shared test database.

**D7. Only the process that loaded the support file prints the line.** A forked child, for example a
round of `rspec --bisect`, runs the exit hook too, while the parent run is still active. Rejected:
an RSpec `after(:suite)` hook. It runs before the summary of RSpec, and a bisect round runs it too.

**D8. The spec pins the line at exit as a literal.** The code prints the line from a `String`
literal, and the spec holds the expected line in a helper. A shared constant let a change of the
line pass every example while the docs still gave the old line.

**D9. The start comes from `Time.now.to_i`.** It gives the same Unix seconds as
`Process.clock_gettime(CLOCK_REALTIME, :second)` with a shorter call. The spec stubs `Time.now` for
the whole example, and nothing else in those examples reads it.

**D10. A run marker that the run cannot open counts as ended.** One such run marker, with mode 000
or another owner, made every later run continue without a run marker. The probe raised, and the run
warned with the wrong cause and never removed it.

Now the probe returns false, and the run removes the run marker with the other run markers of
ended runs when no run is active. A removal needs only write access on the directory. Any other
error of the probe raises, because a wrong answer removes the run marker of an active run. The
rescue of `write` then prints its warning, and the run continues without a run marker.

Rejected: a rule that counts a run marker that the run cannot open as active. A run that ended then
stays in every line until a person removes it, and it stops the removal of the run markers of
every other ended run.

**D11. The child runs of the spec start with `--disable-gems`.** The child runs of the spec need
only `pathname`, and RubyGems was most of their start time. The flag saves about 0.75 s a run of the
spec file. `pathname` loads without RubyGems on Ruby 3.2 to 4.0. Before Ruby 4.0, `Pathname#mkpath`
loads `fileutils`, about 10 ms a child run.

Rejected: a call of `mkpath` only when the directory does not exist. It saves 10 ms a child run of
the spec and nothing in the suite, which loads `fileutils` with Rails before the support file. On
Ruby 4.0, `mkpath` is built in.

**D12. The messages go through `$stderr.puts`, not `Kernel#warn`.** `warn` prints nothing under
`-W0` (`RUBYOPT=-W0`), which a developer sets to hide Ruby warnings. The line at exit is
information, not a warning, and a reader must see the three warnings too. The messages ignore any
error of the write, for example a pipe whose reader is gone or a replaced stderr that cannot take
the message. The `Style/StderrPuts` cop is disabled on that one line.

Rejected: `Warning.warn`. It prints under `-W0` and ignores a write error of the real stderr with no
rescue. A replaced stderr that raises escapes it, and `Warning.warn` is the hook that
warnings-as-errors tools prepend.

## Risks / Trade-offs

- A run killed between the open and the unlink of its temporary file leaves a `.tmp` file that
  nothing removes. The window is microseconds, and the file is empty and ignored by git. A later run
  with the same pid and second then continues without a run marker.
- `File.link` needs hard links. On a file system without them, every run warns and continues
  without a run marker.
- While one run stays active, each start probes every run marker in the directory, about 45 µs
  each on APFS. A run stopped in a debugger for a week beside 50 starts a day leaves about 350 run
  markers, 16 ms a start. The line of the long run then names them all, 27 bytes each. The first
  start with no active run removes them.
- A directory that refuses deletes, for example an append-only directory on Linux or a directory
  with a deny-delete ACL on macOS, breaks the tool. The unlink of the temporary name fails after the
  link, so the run closes its locked file, warns and continues without a run marker. Every start
  then warns about each old run marker it cannot remove. Fix the directory.
