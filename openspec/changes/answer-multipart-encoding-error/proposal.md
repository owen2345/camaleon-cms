# Answer a multipart request with an encoding error of the param parser with a 400

## Why

Rack gives the name of a multipart part the charset of that part (`Content-Type: text/plain;
charset=UTF-16LE`). The param parser of Rack 3.2 compares that name with ASCII text. For a charset
that is not ASCII-compatible, it raises `Encoding::CompatibilityError`. Rack 2.2 raises that error or
a plain `ArgumentError`, by the bytes of the name.

- For a POST, `Rack::MethodOverride` reads the params outside `ActionDispatch::ShowExceptions`. The
  error leaves the middleware stack, and the server answers with a 500.
- For another method, Rails reads the params. `ShowExceptions` reads them again for its error page,
  so the answer is the failsafe 500 of Rails.
- The same holds for each param of each multipart request of the host app: an admin save, a
  frontend form, a controller of the host.

A browser form sends no charset for a part, so only a hand-made request holds such a part. A param
with a broken UTF-8 text already gets a 400 from Rails.

## What Changes

- The engine adds the Rack middleware `CamaleonCms::MultipartEncodingGuard` to the host app,
  directly after `ActionDispatch::Executor`. That position is before `Rack::MethodOverride`.
- The guard reads the params of a multipart request with the parser of Rack. For an encoding error
  of the parser, it answers with a 400. Rack keeps the result of the parse, so Rack and Rails do not
  parse the body again.
- The guard also answers the plain `ArgumentError` that Rack 2.2 raises for such a part.
- Each other error of the parser passes to the next middleware, as before.
- `docs/upgrading-to-2.9.5.md` tells host apps about the middleware.

## Capabilities

### New Capabilities

- `multipart-encoding-error-response`: a multipart request that the param parser of Rack cannot
  read for its encoding gets a 400.

### Modified Capabilities

None.

## Impact

- `lib/camaleon_cms/multipart_encoding_guard.rb` (the middleware), `lib/camaleon_cms/engine.rb` (its
  position in the stack), `lib/camaleon_cms.rb` (the require).
- Specs: `spec/requests/multipart_encoding_guard_spec.rb` and
  `spec/lib/camaleon_cms/multipart_encoding_guard_spec.rb`.
- Each host app gets one more middleware. For a multipart PATCH, PUT or DELETE, the parse of the
  params runs earlier than before.
- Ecosystem: no surveyed consumer changes the middleware stack, is an API-only app, or sets a
  charset for a multipart part. `docs/ai/ecosystem.md` records the survey.
