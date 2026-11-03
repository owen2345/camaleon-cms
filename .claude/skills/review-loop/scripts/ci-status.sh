#!/usr/bin/env bash
# Usage: ci-status.sh <project> <sha> <suite workflows>
#
# Reads the runs of the commit (ci.md). It polls until every suite workflow has a run and every suite run is
# completed. Then it prints one line per suite workflow. Its fields are the name, the id, the attempt and the
# conclusion of its newest run, with " | " between them. After them, it prints one line
# "# advisory <workflow> <conclusion>" per other workflow whose newest run completed with a conclusion other
# than success or skipped.
#
# <sha> is the full SHA of the commit: gh matches no short SHA. <suite workflows> is the names of the suite
# workflows, joined with "|". Each poll prints its number and its answer, except the poll that prints the
# lines. The exit codes:
#   0: every suite run is completed, and the script printed the lines.
#   2: the arguments are wrong, or <sha> is not a full SHA.
#   3: a suite workflow still has no run after five minutes.
#   4: a suite run is still pending after an hour.
#   5: three calls of gh one after the other failed.
# REVIEW_LOOP_SLEEP overrides the 30 seconds between two polls.
set -u
[ $# -eq 3 ] || { echo 'Usage: ci-status.sh <project> <sha> <suite workflows>' >&2; exit 2; }
[[ $2 =~ ^[0-9a-f]{40}$ ]] || { echo 'ci-status.sh: <sha> must be the full SHA of the commit' >&2; exit 2; }
e=0
for i in $(seq 120); do
  if r=$(S="$3" gh run list --repo "$1" --commit "$2" --limit 100 \
    --json workflowName,status,conclusion,databaseId,attempt \
    --jq 'def suite: .workflowName | IN(env.S | split("|")[]);
      def newest: group_by(.workflowName) | map(max_by(.databaseId))[];
      . as $all | map(select(suite))
      | if (unique_by(.workflowName) | length) < (env.S | split("|") | length) then "absent"
        elif all(.status == "completed") then
          (newest | "\(.workflowName) | \(.databaseId) | \(.attempt) | \(.conclusion)"),
          ($all | map(select(suite | not)) | newest
            | select(.status == "completed" and .conclusion != "success" and .conclusion != "skipped")
            | "# advisory \(.workflowName) \(.conclusion)")
        else "pending" end'); then
    e=0
    case "$r" in
      absent) echo "$i absent"; [ "$i" -ge 11 ] && exit 3 ;;
      pending) echo "$i pending" ;;
      *) printf '%s\n' "$r"; exit 0 ;;
    esac
  else
    echo "$i "
    e=$((e + 1))
    [ "$e" -ge 3 ] && exit 5
  fi
  [ "$i" -lt 120 ] && sleep "${REVIEW_LOOP_SLEEP:-30}"
done
exit 4
