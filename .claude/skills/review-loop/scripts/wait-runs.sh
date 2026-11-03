#!/usr/bin/env bash
# Usage: wait-runs.sh [<checkout>]
#
# Waits until no spec run is active, an hour at most (docs/ai/testing.md, Which specs to run). With a
# checkout, a run is active while it holds the lock of a run marker under <checkout>/tmp/rspec-runs. Without
# one, a run of any checkout counts: pgrep -f '[r]spec' names it. Each wait prints its number.
#
# The program is wait_runs.rb beside this script, which the lint reads. One ruby process runs the whole wait.
# Its command line holds that file name, not "rspec", so the pgrep of Linux does not list the wait itself.
# The exit codes:
#   0: no run is active.
#   4: a run is still active after the hour.
# REVIEW_LOOP_SLEEP overrides the 20 seconds between two tests.
set -u
[ $# -le 1 ] || { echo 'Usage: wait-runs.sh [<checkout>]' >&2; exit 2; }
exec ruby --disable=gems "$(dirname "$0")/wait_runs.rb" "$@"
