# The answer of a fake command of the review-loop script specs. The fake sources this file. It writes the
# arguments of the call, with a NUL after them, to $FAKE_CALLS. It takes the first line of $FAKE_ANSWERS as
# the answer. It removes that line, unless it is the last one: a fake repeats its last answer. With STAMPS set,
# it appends the time of the call, in seconds, to that file (stamp_gaps). Else builtins only: a poll calls a
# fake a hundred times.
set -u
[ -z "${STAMPS:-}" ] || perl -MTime::HiRes=time -e 'print time, "\n"' >> "$STAMPS"
printf '%s\0' "$*" >> "$FAKE_CALLS"
answer=
n=0
while IFS= read -r line; do
  if [ "$n" -eq 0 ]; then answer=$line; else rest[$n]=$line; fi
  n=$((n + 1))
done < "$FAKE_ANSWERS"
if [ "$n" -gt 1 ]; then printf '%s\n' "${rest[@]}" > "$FAKE_ANSWERS"; fi
