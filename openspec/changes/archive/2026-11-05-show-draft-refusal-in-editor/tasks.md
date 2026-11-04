# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/features/admin/post_draft_refused_value_spec.rb`: an author who is not an
  administrator saves a draft with a script in a `field_attrs` value, and the alert shows the
  refusal. Confirm that it fails on the unfixed script, which shows "The draft could not be saved"

## 2. The remedy

- [x] 2.1 Read a 422 with a message as a refusal in the `error` handler of `draft_request`, through
  the `refused` function that the 200 path uses (D1, D2)

## 3. Documentation

- [x] 3.1 Name the new message in `docs/upgrading-to-2.9.5.md`

## 4. Verification and release steps

- [x] 4.1 `bin/rubocop -A`, `bin/rspec` on the new spec and the adjacent ones,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Push to PR #1335, fold the change into its description, archive this change on the branch
