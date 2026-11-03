# The grammar of a ledger line (procedure.md, Ledger rows): fields with " | " between them. The three ledger
# scripts load this file before their own program.

# The fields of a line, in a. Returns their count.
function fields(line, a) { return split(line, a, " \\| ") }

# The compact form of a PASS line: the pass, the HEAD pair and the state, the field before the last.
function pass_compact(line,   a, n) { n = fields(line, a); return a[1] " | " a[2] " | " a[n - 1] }

# The <after> of a PASS line: the last word of its HEAD pair.
function pass_after(line,   a, w, n) { fields(line, a); n = split(a[2], w, " "); return w[n] }

# The compact form of a FIXED row: the pass, the location and the category.
function fixed_compact(line,   a, n) {
  sub(/ \| FIXED \| .*$/, "", line)
  n = fields(line, a)
  return a[1] " | " a[n - 1] " | " a[n]
}
