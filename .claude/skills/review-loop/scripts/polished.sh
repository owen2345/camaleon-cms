#!/usr/bin/env bash
# Usage: polished.sh <ledger> <checkout>
#
# Prints the <after> of the newest PASS line of a pass whose review ran (setup.md, Ledger). Such a PASS line
# names a pass 1 to 8, and a "review" line precedes it. A PASS line that the ledger holds twice counts once.
# Prints "none" when the ledger has no such line, or when the checkout lacks that commit. Exits with the code
# of awk for a ledger that it cannot read. The program is polished.awk, with the grammar of ledger.awk.
set -u
[ $# -eq 2 ] || { echo 'Usage: polished.sh <ledger> <checkout>' >&2; exit 2; }
after=$(LC_ALL=C awk -f "$(dirname "$0")/ledger.awk" -f "$(dirname "$0")/polished.awk" "$1") || exit $?
if [ -n "$after" ] && git -C "$2" rev-parse -q --verify "$after^{commit}" > /dev/null; then
  echo "$after"
else
  echo none
fi
