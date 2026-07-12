## 1. Implement Nokogiri SVG content checker

- [x] 1.1 Create `lib/camaleon_cms/svg_content_checker.rb` module with an `unsafe?(svg_content)` method that parses SVG with Nokogiri, checks for `<script>` elements, `on*` attributes, `href`/`xlink:href` with `javascript:` URIs, and returns true if dangerous content is found
- [x] 1.2 Handle XML parse errors: rescue `Nokogiri::XML::SyntaxError` and return unsafe (reject on unparseable content)
- [x] 1.3 Add test fixtures: SVG with `<script>`, SVG with `onclick`, SVG with entity-encoded `javascript:`, SVG with DTD entity, safe SVG
- [x] 1.4 Add unit tests for `SvgContentChecker.unsafe?` covering all fixture cases

## 2. Integrate SVG content checker into upload pipeline

- [x] 2.1 In `runtime_uploader_concern.rb`: after `file_content_unsafe?` check, add SVG detection (`.svg` extension) and call `SvgContentChecker.unsafe?` — reject upload if dangerous
- [x] 2.2 In `uploader_helper.rb`: same integration at the corresponding point in the duplicated `upload_file` method
- [x] 2.3 Update `file_content_unsafe?` to skip regex scanning for SVG files (they're handled by the parse-based checker)
- [x] 2.4 Add integration test: upload SVG with `onclick` → upload rejected with error message

## 3. Implement Rack middleware for SVG security headers

- [x] 3.1 Create `lib/camaleon_cms/media_security_headers.rb` middleware class that intercepts `PATH_INFO` matching `/media/.*\.svg\z` and adds `X-Content-Type-Options: nosniff` and `Content-Security-Policy: script-src 'none'`
- [x] 3.2 Register middleware in `lib/camaleon_cms/engine.rb` using `insert_before ActionDispatch::Static`
- [x] 3.3 Add request spec: SVG under `/media/` responds with nosniff and CSP headers
- [x] 3.4 Add request spec: PNG under `/media/` does NOT get security headers

## 4. Clean up redundant code

- [x] 4.1 Add deprecation comment to `UNSAFE_EVENT_PATTERNS` and `SUSPICIOUS_PATTERNS` in `lib/camaleon_cms/content_security.rb` (retained for non-SVG file scanning)
- [x] 4.2 Remove `include ContentSecurity` from `runtime_uploader_concern.rb` and `uploader_helper.rb` (replaced references with `CamaleonCms::ContentSecurity::SUSPICIOUS_PATTERNS`)
- [x] 4.3 Remove existing `file_content_unsafe?` tests for SVG files that are now handled by the parse-based checker

## 5. Final verification

- [x] 5.1 Run `bin/rubocop -A` (lint)
- [x] 5.2 Run `bin/brakeman --no-pager` (security) — 0 warnings
- [x] 5.3 Run `(cd spec/dummy && bin/rails zeitwerk:check)` (load verification) — all good
- [x] 5.4 Run `bin/rspec` (full test suite) — 124 examples, 0 failures
