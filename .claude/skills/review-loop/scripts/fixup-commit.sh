#!/usr/bin/env bash
# Usage: fixup-commit.sh <checkout> <before> <after> <sha>
#
# Commits the failure fix as "fixup! <sha>" (docs/ai/workflows.md, Phase 3). <before> is the tree of the
# checkout with the uncommitted fix, and <after> that tree with the failure fix on top. The difference of the
# two trees is the failure fix. The commit comes from a temporary index, so that no file of the checkout
# changes. Before the commit, the script sets the entries of the real index for the paths of the difference to
# <after>. After the commit, git status shows no change for a path that only the failure fix changed. A path
# that the uncommitted fix changed too shows a staged change. A failed commit puts the real index back.
#
# The plumbing diff-tree ignores the prefix, context, color and external-diff settings of the user. The apply
# ignores the whitespace settings of the user. The reset takes each path as it is, not as a pathspec. The exit
# codes:
#   0: the script made the fixup commit.
#   1: the apply refused the difference: the two fixes are related.
#   3: another command failed, and the script made no fixup commit.
# Any other code is the code of the diff or the apply.
set -uo pipefail
[ $# -eq 4 ] || { echo 'Usage: fixup-commit.sh <checkout> <before> <after> <sha>' >&2; exit 2; }
dir=$(mktemp -d) || exit 3
trap 'rm -rf "$dir"' EXIT
real="$(git -C "$1" rev-parse --absolute-git-dir)/index" || exit 3
export GIT_INDEX_FILE="$dir/index"
git -C "$1" read-tree HEAD || exit 3
git -C "$1" diff-tree -p --binary "$2" "$3" | git -C "$1" apply --cached --3way --whitespace=nowarn || exit $?
[ ! -e "$real" ] || cp -p "$real" "$dir/real" || exit 3
git -C "$1" diff-tree -r --name-only -z "$2" "$3" |
  env -u GIT_INDEX_FILE git --literal-pathspecs -C "$1" reset -q "$3" --pathspec-from-file=- --pathspec-file-nul || exit 3
git -C "$1" commit -q -m "fixup! $4" && exit 0
[ ! -e "$dir/real" ] || cp -p "$dir/real" "$real"
exit 3
