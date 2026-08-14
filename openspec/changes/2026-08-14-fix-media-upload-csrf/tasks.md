# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/security/media_upload_csrf_spec.rb`: with forgery protection enabled, a
  token-less `POST /admin/media/upload` must be rejected; the media browser GET is unaffected
- [x] 1.2 Confirm the CSRF example fails against the unfixed action (skip present → no raise)

## 2. Fix

- [x] 2.1 Remove `skip_before_action :verify_authenticity_token, only: :upload`
- [x] 2.2 Send the CSRF token as an `authenticity_token` form field from the `uploadFile`
  `dynamicFormData` hook in `_media_manager.js`

## 3. Verification

- [x] 3.1 `bin/rubocop` on the touched files — no offenses
- [x] 3.2 `bin/rspec` on the reproduction spec and `spec/requests/admin/media_controller/upload_spec.rb`
  — green
- [ ] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [ ] 3.4 Changelog + archive at ship time
