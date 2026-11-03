#!/usr/bin/env bash
# Usage: checkout-tree.sh <checkout>
#
# Prints the tree of the checkout with every change staged (procedure.md, Checks). It stages into a copy of
# the index, so the index of the checkout does not change. The stat data of the copy spares a read of every
# tracked file. The copy keeps the mtime of the index, so git still compares a file changed in the same second
# as the index (a racy entry). Exits with the code of the git command that fails.
set -u
[ $# -eq 1 ] || { echo 'Usage: checkout-tree.sh <checkout>' >&2; exit 2; }
dir=$(mktemp -d) || exit 2
trap 'rm -rf "$dir"' EXIT
git_dir=$(git -C "$1" rev-parse --absolute-git-dir) || exit $?
[ -e "$git_dir/index" ] && cp -p "$git_dir/index" "$dir/index"
export GIT_INDEX_FILE="$dir/index"
git -C "$1" add -A && git -C "$1" write-tree
