#!/usr/bin/env bash
# Usage: wait-log.sh <log>
#
# Waits for the end of a background task (docs/ai/testing.md, Long commands). It reads the log every five
# seconds, and gives up at the first read after 570 seconds. Then it prints one word, the summary line of a
# spec run and the last three lines of the log. The word:
#   end: the log has the end line.
#   missing: the log does not exist.
#   stale: the log did not change for 30 minutes.
#   bound: 570 seconds passed, and the command still runs.
# REVIEW_LOOP_SLEEP overrides the five seconds, and REVIEW_LOOP_BOUND the 570 seconds.
set -u
[ $# -eq 1 ] || { echo 'Usage: wait-log.sh <log>' >&2; exit 2; }
w=bound
while :; do
  grep -aqE '^\[(exited with code [0-9]+|killed)\]$' "$1" 2> /dev/null && { w=end; break; }
  [ -e "$1" ] || { w=missing; break; }
  [ -z "$(find "$1" -mmin -30)" ] && { w=stale; break; }
  [ "$SECONDS" -lt "${REVIEW_LOOP_BOUND:-570}" ] || break
  sleep "${REVIEW_LOOP_SLEEP:-5}"
done
echo "$w"
[ -e "$1" ] || exit 0
grep -aE '^[0-9]+ examples?, ' "$1"
tail -n 3 "$1"
exit 0
