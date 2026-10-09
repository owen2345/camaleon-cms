# Tasks

## 1. The run marker

- [x] 1.1 Add `spec/support/run_marker.rb` (D1 to D7, D9, D10 and D12) with:
  - the write, which locks the run marker before the run marker gets its name
  - the line at exit
  - the three warnings
  - the removal of old run markers
- [x] 1.2 Add `spec/rspec_run_marker_spec.rb` (D8 and D11) with examples for:
  - child runs that name each other
  - a failed run and a killed run
  - a run without a run marker
  - the write, the removal and the list

## 2. Documentation

- [x] 2.1 Add `docs/ai/run-markers.md` and the pointer in `docs/ai/testing.md`
- [x] 2.2 Add the CHANGELOG entry

## 3. Verification

- [x] 3.1 `bin/rubocop -A` on the touched files, `bin/rspec spec/rspec_run_marker_spec.rb`,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 3.2 Archive this change on the branch
