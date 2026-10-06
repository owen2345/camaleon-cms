# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/multipart_encoding_guard_spec.rb`. A multipart POST and PATCH with a
  part in UTF-16 get a 400 and store nothing. Confirm that the examples fail on the unfixed code

## 2. The remedy

- [x] 2.1 Add `CamaleonCms::MultipartEncodingGuard`, which answers an `EncodingError` of the param
  parser with a 400 (D1, D2, D3)
- [x] 2.2 Install the guard directly after `ActionDispatch::Executor` (D4)
- [x] 2.3 Add `spec/lib/camaleon_cms/multipart_encoding_guard_spec.rb`: the answer, the upload files
  and the requests that pass
- [x] 2.4 Answer the plain `ArgumentError` of Rack 2.2 for a part name with broken bytes, with
  examples (D5)

## 3. Documentation

- [x] 3.1 Add the note for host apps to `docs/upgrading-to-2.9.5.md`
- [x] 3.2 Record the survey of the consumers in `docs/ai/ecosystem.md`

## 4. Verification and release steps

- [x] 4.1 `bin/rubocop -A` on the touched files, `bin/rspec` on the new specs and the adjacent ones,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
