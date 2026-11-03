# The awk program of verdicts.sh, which says what it prints. V is the verdicts to match, as "A|B", and the
# verdict of a row is its first field from the third on that matches V. The grammar of a line is in ledger.awk.
/^setup HEAD / { cur = $3; for (i = 1; i <= nb; i++) print b[i] " | " cur; nb = 0; next }
{
  n = fields($0, f)
  for (i = 3; i < n; i++) if (f[i] ~ "^(" V ")$") break
  if (i >= n) next
  m = f[1]
  for (j = 2; j <= i - 2; j++) m = m " | " f[j]
  m = m " | " f[i]
  e = ""
  for (j = i + 1; j <= n; j++) e = e (j > i + 1 ? " | " : "") f[j]
  h = ""
  while (match(e, /judged at [0-9a-f]+/)) { h = substr(e, RSTART + 10, RLENGTH - 10); e = substr(e, RSTART + RLENGTH) }
  if (h == "") h = cur
  if (h == "") b[++nb] = m; else print m " | " h
}
