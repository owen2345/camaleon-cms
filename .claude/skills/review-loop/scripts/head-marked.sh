#!/usr/bin/env bash
# Usage: head-marked.sh <checkout> <sha>
#
# Exits with 0 when the commit carries a skip marker (ci.md). A marker is a bracket marker of
# docs/ai/workflows.md Phase 3 in the message, or a "skip-checks: true" trailer after two empty lines at the
# end. A skip-checks line anywhere else does not mark it. Exits with 1 when the commit is not marked, and with
# 2 when git cannot read it. The script reads the commit object once: its message is the part after the first
# empty line. The x after the object keeps its final newlines, which a command substitution drops.
set -u
# grep and tr read bytes: a message in another encoding, or with a stray byte, is still a message.
export LC_ALL=C
[ $# -eq 2 ] || { echo 'Usage: head-marked.sh <checkout> <sha>' >&2; exit 2; }
raw=$(git -C "$1" cat-file commit "$2" && echo x) || exit 2
raw=${raw%x}
message=${raw#*$'\n\n'}
printf '%s' "$message" | grep -qF -e '[skip ci]' -e '[ci skip]' -e '[no ci]' -e '[skip actions]' -e '[actions skip]' && exit 0
printf '%s' "$raw" | tail -n 3 | tr '\n' '|' | grep -qE '^\|\|skip-checks: ?true\|?$' && exit 0
exit 1
