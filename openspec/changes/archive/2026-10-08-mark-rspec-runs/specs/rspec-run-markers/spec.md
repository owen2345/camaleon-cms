## ADDED Requirements

### Requirement: Each run of the Camaleon suite leaves a locked run marker

When the support files of the Camaleon suite load, the run SHALL create an empty file
`tmp/rspec-runs/rspec-<pid>-<start>.pid` under the repo root, its run marker. `<start>` is the Unix
time of the load in seconds. The run SHALL hold a lock on its run marker until its process ends. It
SHALL NOT wait for another run or refuse to start because of one. The run SHALL lock the file before
the file gets that name, so that no other run finds the run marker unlocked. Until then, the file
has a temporary name, which no run counts as a run marker.

A file in `tmp/rspec-runs` with another name is not a run marker. The line at exit and the removal
of old run markers ignore it.

A run that cannot write its run marker SHALL print
`RspecRunMarker: no run marker for this run: <error>` on stderr. It SHALL continue without a run
marker, with the same exit status.

#### Scenario: A run writes and locks its run marker

- **WHEN** the support files of a run load
- **THEN** `tmp/rspec-runs` holds an empty run marker with the pid and the start of the run
- **AND** a shared lock on it fails while the run is active

#### Scenario: Another run holds the lock of its run marker

- **WHEN** a run probes the run marker of an active run
- **THEN** the probe returns at once, and the run does not wait for that run

#### Scenario: The run marker never appears unlocked

- **WHEN** another run lists the directory while this run writes its run marker
- **THEN** it finds the run marker under its name only with the lock held

#### Scenario: A killed run releases its lock

- **WHEN** another process kills the run and its forked children without their exit hooks
- **THEN** a shared lock on its run marker succeeds

#### Scenario: The run marker directory does not exist

- **WHEN** a run loads in a checkout without `tmp/rspec-runs`
- **THEN** the run creates the directory and writes its run marker

#### Scenario: A file that is not a run marker is in the directory

- **WHEN** `tmp/rspec-runs` holds a file with another name, for example `notes.txt` or a `.tmp` file
- **THEN** the line at exit and the removal of old run markers ignore it

#### Scenario: The run cannot write its run marker

- **WHEN** the run cannot create, lock or link its temporary file, for example because `tmp` is a file
- **THEN** the run prints the warning, continues and exits with the status of its examples
- **AND** the run removes only a temporary file that it made

#### Scenario: A file exists under the name of the run marker or under its temporary name

- **WHEN** a file exists under `rspec-<pid>-<start>.pid` or under the temporary name
  `rspec-<pid>-<start>.pid.tmp` when the run writes, for example the run marker of an active run
- **THEN** the run keeps that file, prints the warning and continues without a run marker

### Requirement: At exit a run names the run markers of the runs that overlapped it

At exit, the process that loaded the support files SHALL print one line on stderr when another run
overlapped it. A run overlapped this run when it was active at the load of this run or wrote its run
marker later. The line is `RspecRunMarker: other runs during this run: <names>`, with the names in
sorted order. The line SHALL come after the summary of RSpec. A forked child of the run SHALL NOT
print the line.

A run counts as active while its process holds the lock on its run marker. A run marker that is
gone, or that the run has no permission to open, counts as ended.

A run without a run marker SHALL print `RspecRunMarker: no run marker for this run` at exit in
place of the line. When the run cannot list the run markers at exit, it SHALL print
`RspecRunMarker: cannot list the run markers at exit: <error>` and no line. The exit status of
the run SHALL NOT change.

#### Scenario: Two runs overlap

- **WHEN** run B loads while run A is active, and both end later
- **THEN** the line of A names the run marker of B, and the line of B names the run marker of A

#### Scenario: A run starts and ends during this run

- **WHEN** run B loads after run A and ends before A exits
- **THEN** the line of A names the run marker of B

#### Scenario: No other run was active

- **WHEN** only run markers of ended runs exist during the run
- **THEN** the run prints nothing on stderr at exit

#### Scenario: Ruby warnings are off

- **WHEN** the run starts with `RUBYOPT=-W0`, which silences `Kernel#warn`
- **THEN** the run still prints the line and the warnings

#### Scenario: A forked child exits

- **WHEN** a forked child of the run, for example a round of `rspec --bisect`, exits
- **THEN** the child prints no line, and the run prints its line once at its own exit

#### Scenario: The run has no run marker

- **WHEN** the run could not write its run marker at load
- **THEN** the run prints `RspecRunMarker: no run marker for this run` at exit

#### Scenario: The run marker directory is gone at exit

- **WHEN** `tmp/rspec-runs` was removed or made unreadable during the run
- **THEN** the run prints the warning and no line, and its exit status is unchanged

### Requirement: A run removes the run markers of ended runs only when no run is active

Before a run writes its own run marker, it SHALL remove every run marker of an ended run when no
run is active. It SHALL NOT remove a run marker while a run is active. A run marker that another
run removed first SHALL cause no warning. When the run cannot remove a run marker, it SHALL print
`RspecRunMarker: cannot remove an old run marker: <error>` and continue.

#### Scenario: A run is active

- **WHEN** a run holds the lock of its run marker, and run markers of ended runs exist
- **THEN** the next run keeps every run marker, also one with an earlier start in its name

#### Scenario: No run is active

- **WHEN** no process holds the lock of any run marker
- **THEN** the next run removes every run marker it found

#### Scenario: A run marker that the run cannot open

- **WHEN** no run is active and the next run has no permission to open a run marker
- **THEN** it counts the run as ended and removes the run marker

#### Scenario: The probe of a run marker fails

- **WHEN** the probe of a run marker raises a system error other than a file that does not exist or a
  refused permission
- **THEN** the run prints `RspecRunMarker: no run marker for this run: <error>`, removes no run marker
  and continues without a run marker

#### Scenario: A removal fails

- **WHEN** the removal of an old run marker raises a system error other than a file that does not exist
- **THEN** the run prints the warning once, keeps that run marker and writes its own

### Requirement: The docs tell how to read the line at exit

`docs/ai/run-markers.md` SHALL describe the line at exit, the runs that the line cannot show, and
the warnings with what a reader must do after each. `docs/ai/testing.md` SHALL point to that
document.

#### Scenario: A session sees a RspecRunMarker line

- **WHEN** a session finds a `RspecRunMarker` line in the output of a run
- **THEN** `docs/ai/testing.md` sends it to `docs/ai/run-markers.md`, which tells what the line
  means and what the session must do
