#!/usr/bin/env bash
# Usage: ci-jobs.sh <project> <run id> [<attempt>]
#
# Prints the jobs of a workflow run that did not pass (ci.md), one per line. A line holds the job id, its
# conclusion, the count of its failed steps and its name. With <attempt>, a number, reads the jobs of that
# attempt. Exits with the code of gh, and with 2 for wrong arguments or an <attempt> that is not a number.
set -u
[ $# -eq 2 ] || [ $# -eq 3 ] || { echo 'Usage: ci-jobs.sh <project> <run id> [<attempt>]' >&2; exit 2; }
[ $# -eq 2 ] || [[ $3 =~ ^[0-9]+$ ]] || { echo 'ci-jobs.sh: <attempt> must be a number' >&2; exit 2; }
gh run view "$2" --repo "$1" ${3:+--attempt "$3"} --json jobs \
  --jq '.jobs[] | select(.conclusion != "success" and .conclusion != "skipped") | "\(.databaseId) \(.conclusion) \([.steps[] | select(.conclusion == "failure")] | length) \(.name)"'
