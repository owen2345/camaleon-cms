#!/usr/bin/env bash
# Usage: run-state.sh <ledger>
#
# The second read of a pass (procedure.md, Pass start). Prints the state lines of the last run and every line
# after its last PASS line. A PASS line prints as "pass | HEAD pair | state", and a FIXED row before that PASS
# line as "pass | location | category". Exits with the code of the first command that fails. The program is
# run-state.awk, with the grammar of ledger.awk.
set -uo pipefail
[ $# -eq 1 ] || { echo 'Usage: run-state.sh <ledger>' >&2; exit 2; }

"$(dirname "$0")/this-run.sh" "$1" | LC_ALL=C awk -f "$(dirname "$0")/ledger.awk" -f "$(dirname "$0")/run-state.awk"
