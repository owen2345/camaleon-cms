# The awk program of polished.sh, which says what it prints. The grammar of a line is in ledger.awk.
/^PASS [1-8]\// && !s[$0]++ { if (r) p = $0; r = 0 }
/^review$/ { r = 1 }
END { if (p) print pass_after(p) }
