#!/usr/bin/env bash
# Usage: this-run.sh <ledger>
#
# Prints the lines of the last run of the ledger, from its "## Run" header on (procedure.md, Pass start).
# Exits with 1 when the ledger has no run header.
set -u
[ $# -eq 1 ] || { echo 'Usage: this-run.sh <ledger>' >&2; exit 2; }
n=$(grep -an '^## Run ' "$1" | tail -n 1 | cut -d: -f1)
[ -n "$n" ] || exit 1
tail -n +"$n" "$1"
