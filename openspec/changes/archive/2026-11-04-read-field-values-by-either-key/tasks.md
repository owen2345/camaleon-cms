# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/models/custom_field_value_string_keys_spec.rb`: a plain Hash with String keys, a
  `JSON.parse` result, and request parameters. The examples cover a stored and a refused group
  number, mixed key types, and the Hash of the caller. Five of seven examples are red against the
  unfixed method

## 2. The fix

- [x] 2.1 Read a plain Hash with indifferent access in `set_field_values` (D1); the 1.1 spec passes
- [x] 2.2 Refuse a String key and its Symbol twin before the delete (D3). Two examples of the 1.1
  spec are red against 2.1

## 3. Documentation

- [x] 3.1 Tell plugin developers in `docs/upgrading-to-2.9.5.md` that such a call stores its values
  now (an at-a-glance row and a note). Record the survey of the callers in `docs/ai/ecosystem.md`

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A`, the whole suite (the concern is in most models), `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
