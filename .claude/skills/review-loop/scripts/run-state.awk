# The awk program of run-state.sh, which says what it prints. The grammar of a line is in ledger.awk.
/^PASS / { p = NR }
{ l[NR] = $0 }
END {
  for (i = 1; i <= NR; i++)
    if (l[i] ~ /^PASS /) print pass_compact(l[i])
    else if (i > p || l[i] ~ /^(## Run|setup |ci )/) print l[i]
    else if (l[i] ~ /\| FIXED \|/) print fixed_compact(l[i])
}
