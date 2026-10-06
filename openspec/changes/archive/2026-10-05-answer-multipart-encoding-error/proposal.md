# Answer a multipart request that Rack cannot parse for its encoding with a 400

## Why

A part of a multipart request can name a charset (`Content-Type: text/plain; charset=UTF-16LE`),
and Rack gives that charset to the name of the part too. For a charset that is not
ASCII-compatible, the param parser of Rack 3.2 raises `Encoding::CompatibilityError`. Rack 2.2
raises that error or a plain `ArgumentError`. The server then answers with a 500:

- For a POST, `Rack::MethodOverride` parses the params outside `ActionDispatch::ShowExceptions`, so
  the error leaves the middleware stack.
- For another method, Rails parses the params. `ShowExceptions` reads them again for its error
  page, so the answer is the failsafe 500 of Rails.

This applies to each multipart request of the host app: an admin save, a frontend form, a
controller of the host. No browser form sends such a part. A param in invalid UTF-8 already gets a
400 from Rails.

## What Changes

- Camaleon adds the Rack middleware `CamaleonCms::MultipartEncodingGuard` to the host app, directly
  after `ActionDispatch::Executor`. That position is before `Rack::MethodOverride`.
- The guard parses the params of a multipart request with the parser of Rack. It answers an
  encoding error of the parser with a 400. Rack keeps the result of the parse for the calls that
  come later.
- The guard also answers the plain `ArgumentError` that Rack 2.2 raises for such a part.
- Each other error of the parser passes to the next middleware, as before.
- `docs/upgrading-to-2.9.5.md` tells host apps about the middleware.

## Capabilities

### New Capabilities

- `multipart-encoding-error-response`: a multipart request that the param parser of Rack cannot
  parse for its encoding gets a 400.

### Modified Capabilities

None.

## Impact

- `lib/camaleon_cms/multipart_encoding_guard.rb` (the middleware), `lib/camaleon_cms/engine.rb` (its
  position in the stack), `lib/camaleon_cms.rb` (the require).
- Specs: `spec/requests/multipart_encoding_guard_spec.rb` and
  `spec/lib/camaleon_cms/multipart_encoding_guard_spec.rb`.
- Each host app gets one more middleware. For each method other than POST, and for a POST in an
  API-only host, the parse of the params of a multipart request runs earlier than before.
- Ecosystem: no surveyed consumer changes the middleware stack, is an API-only app, or sets a
  charset for a multipart part. `docs/ai/ecosystem.md` records the survey.
