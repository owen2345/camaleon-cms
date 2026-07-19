## 1. Core Implementation

- [x] 1.1 Add URL validation to the `crop` action: wrap the `cama_tmp_upload` call with a guard that validates HTTP/HTTPS URLs via `UserUrlValidator.validate(url, reject_path_traversal: true)`, returning a bad request error for invalid URLs. Non-URL paths and data URIs pass through unchanged.

## 2. Testing

- [x] 2.1 Add request specs for `crop` action URL validation covering:
      - Valid same-origin HTTP URL passes through
      - HTTP URL with `..` path segments is rejected
      - Non-URL path is passed through (no controller-level validation)
      - data: URI is passed through (no controller-level validation)

## 3. Verification

- [x] 3.1 Run `bin/rubocop -A` and fix any lint issues
- [x] 3.2 Run the crop request specs and confirm they pass: `bin/rspec spec/requests/admin/media_controller/crop_spec.rb`
- [x] 3.3 Run the full test suite: `bin/rspec`
