#!/usr/bin/env bash
# Usage: verdicts.sh <ledger>
#
# The first read of a pass (procedure.md, Pass start). Prints the REFUTED, DECISION and CONFLICT rows of the
# whole ledger, then the DEFERRED rows of the last run. A row prints as "pass | claim | location | verdict |
# HEAD". The HEAD is the SHA after the last "judged at" of the evidence, else the setup HEAD of the row's run. A
# row before the first setup HEAD line gets the setup HEAD of the first run.
#
# Exits with the code of the first command that fails. The program is verdicts.awk, with the grammar of
# ledger.awk.
set -uo pipefail
[ $# -eq 1 ] || { echo 'Usage: verdicts.sh <ledger>' >&2; exit 2; }

rows() {
  LC_ALL=C awk -v V="$1" -f "$(dirname "$0")/ledger.awk" -f "$(dirname "$0")/verdicts.awk"
}

rows 'REFUTED|DECISION|CONFLICT' < "$1" && "$(dirname "$0")/this-run.sh" "$1" | rows DEFERRED
