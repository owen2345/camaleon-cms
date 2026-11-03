#!/usr/bin/env bash
# Usage: ci-newest-head.sh <project> <head> <suite workflows>
#
# Prints the head SHA of the newest suite run of the branch (setup.md, CI), and nothing when the branch has no
# suite run. <suite workflows> is the names of the suite workflows, joined with "|". Exits with the code of gh.
set -u
[ $# -eq 3 ] || { echo 'Usage: ci-newest-head.sh <project> <head> <suite workflows>' >&2; exit 2; }
S="$3" gh run list --repo "$1" --branch "$2" --limit 100 --json headSha,workflowName \
  --jq '[.[] | select(.workflowName | IN(env.S | split("|")[]))] | .[0].headSha // empty'
