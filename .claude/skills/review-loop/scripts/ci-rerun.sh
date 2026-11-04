#!/usr/bin/env bash
# Usage: ci-rerun.sh <project> <run id> <attempt>
#
# Gives a workflow run its one rerun (ci.md). <attempt> is the attempt of the run before the rerun. The script
# reads the attempt of the run first. A number above <attempt> means that the run got its rerun, so the script
# asks GitHub for none. When the run shows <attempt>, the script reruns the failed jobs of the run, or the whole
# run when GitHub refuses that. A refusal is an error output of gh with "cannot be rerun" or an HTTP 4xx status.
# A refusal with "already running" counts as an accepted rerun: a rerun of the run runs already, for example
# from a start of the script that exited with 4.
#
# After the rerun, the script reads the attempt again, six times at most, until the number is above <attempt>.
# Each read prints its count and the attempt that it got, or only its count when gh failed. The read before the
# rerun has the count 0. The exit codes:
#   0: the attempt of the run is above <attempt>.
#   1: GitHub refused the rerun of the whole run.
#   2: the arguments are wrong. <run id> must be a number, and <attempt> a number above 0 and not above the
#      attempt that the run shows.
#   4: the attempt did not rise in the six reads after the rerun, so the rerun has no result.
#   5: the read before the rerun gave no number, or the rerun failed for a reason other than a refusal. The
#      rerun has no result.
# REVIEW_LOOP_SLEEP overrides the 10 seconds between two reads after the rerun.
set -u
[ $# -eq 3 ] || { echo 'Usage: ci-rerun.sh <project> <run id> <attempt>' >&2; exit 2; }
[[ $2 =~ ^[0-9]+$ ]] || { echo 'ci-rerun.sh: <run id> must be a number' >&2; exit 2; }
[[ $3 =~ ^[1-9][0-9]*$ ]] || { echo 'ci-rerun.sh: <attempt> must be a number above 0' >&2; exit 2; }
# True when the attempt that a read got is a number above <attempt>.
above() { [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -gt "$2" ]; }
# Asks GitHub for a rerun, with the options after the project and the run id. Returns 0 when GitHub accepted
# it or the run runs already, and 1 when GitHub refused it. Exits with 5 when gh failed in another way. Prints
# the error output of gh.
rerun() {
  local out
  out=$(gh run rerun "$2" --repo "$1" "${@:3}" 2>&1) && return 0
  printf '%s\n' "$out" >&2
  [[ $out == *'already running'* ]] && return 0
  [[ $out == *'cannot be rerun'* || $out =~ HTTP\ 4[0-9][0-9] ]] && return 1
  exit 5
}
attempt=$(gh run view "$2" --repo "$1" --json attempt --jq .attempt) || attempt=
echo "0 $attempt"
[[ $attempt =~ ^[0-9]+$ ]] || exit 5
[ "$attempt" -gt "$3" ] && exit 0
[ "$attempt" -lt "$3" ] && { echo "ci-rerun.sh: <attempt> is $3, but the run shows the attempt $attempt" >&2; exit 2; }
rerun "$1" "$2" --failed || rerun "$1" "$2" || exit 1
for i in $(seq 6); do
  attempt=$(gh run view "$2" --repo "$1" --json attempt --jq .attempt) || attempt=
  echo "$i $attempt"
  above "$attempt" "$3" && exit 0
  [ "$i" -lt 6 ] && sleep "${REVIEW_LOOP_SLEEP:-10}"
done
exit 4
