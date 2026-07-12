## 1. Add path prefix validation to runtime_uploader_concern.rb

- [x] 1.1 Add path prefix validation guard before `File.open(uploaded_io)` in `upload_file` (line 22) — check path starts with `Rails.public_path` or `Dir.tmpdir`
- [x] 1.2 Add same path prefix validation guard before `File.open(uploaded_io)` in `cama_tmp_upload` (line 222)
- [x] 1.3 Fix format validation bypass — coerce `settings[:formats]` to `'*'` if nil after the `.merge!` call

## 2. Add path prefix validation to uploader_helper.rb

- [x] 2.1 Add path prefix validation guard before `File.open(uploaded_io)` in `upload_file` (line 44) — check path starts with `Rails.public_path` or `Dir.tmpdir`
- [x] 2.2 Add same path prefix validation guard before `File.open(uploaded_io)` in `cama_tmp_upload` (line 297)
- [x] 2.3 Fix format validation bypass — coerce `settings[:formats]` to `'*'` if nil after the `.merge!` call

## 3. Add test coverage

- [x] 3.1 Add request spec: `POST /admin/media/upload` with `file_upload=/etc/hostname` returns error
- [x] 3.2 Add request spec: `GET /admin/media/crop` with `cp_img_path=/etc/passwd` returns error
- [x] 3.3 Add request spec: legitimate multipart file upload still succeeds
- [x] 3.4 Add helper spec: `upload_file` with string path to system file returns error
- [x] 3.5 Add helper spec: `cama_tmp_upload` with string path to system file returns error
- [x] 3.6 Add helper spec: upload without `formats` param respects default format validation

## 4. Final verification

- [x] 4.1 Run `bin/rubocop -A` (lint)
- [x] 4.2 Run `bin/brakeman --no-pager` (security)
- [x] 4.3 Run `(cd spec/dummy && bin/rails zeitwerk:check)` (load verification)
- [x] 4.4 Run `bin/rspec` (full test suite)
