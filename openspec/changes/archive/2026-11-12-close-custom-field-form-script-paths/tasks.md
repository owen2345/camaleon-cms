# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/security/custom_field_form_get_values_spec.rb`. Its GET examples
  open the form of a new post and of an existing post. The form must show no value of the query.
  A failed create must show the submitted values. Make sure that the GET examples fail before the fix.
- [x] 1.2 Add `spec/features/admin/custom_field_image_preview_spec.rb`. Store an image value with a
  quote and an `img` tag. The preview must hold one link and one image, and no handler must run. Make
  sure that the example fails before the fix.

## 2. Fix

- [x] 2.1 Show submitted values only for a request that is not a GET (D1). The 1.1 spec passes.
- [x] 2.2 Set the URL of the image preview as attribute values (D2). The 1.2 spec passes.
- [x] 2.3 Send the submitted values of `spec/requests/security/xss_vulnerabilities_spec.rb` in a POST
  request

## 3. Documentation

- [x] 3.1 Give the GET change in `docs/upgrading-to-2.9.5.md`

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
