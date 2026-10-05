# Design

## Context

See proposal.md, "Why". The error comes from the param parser of Rack before a controller action
starts, so no `rescue_from` of a controller sees it.

## Goals / Non-Goals

**Goals:**

- A multipart request with a part in a charset that is not ASCII-compatible gets a 400, for each
  request method.
- Each other request gets the same answer as before.
- The boot of a host app does not depend on a middleware that the host can lack.

**Non-Goals:**

- A change of the param parser of Rack or of Rails.
- A 400 for each error of the param parser. A truncated multipart body keeps its answer.

## Decisions

**D1. A Rack middleware of the engine reads the params first.** The maintainer chose it on
2026-10-05. `CamaleonCms::MultipartEncodingGuard` reads the params of a multipart request with
`Rack::Request#POST`. `Rack::MethodOverride` and Rails read the params with the same call. Rack keeps
the result in the env, so the later readers do not parse the body again. The guard answers an
`EncodingError` of that call with a 400 and the text `Bad Request`. It writes one line to the error
stream of the request (`rack.errors`), as `Rack::MethodOverride` does for the errors that it handles.

The other remedies were:

- An entry in `config.action_dispatch.rescue_responses`. It does not cover the POST, and the other
  methods keep the failsafe 500, because `ShowExceptions` reads the params again.
- A newer Rack. On 2026-10-05, the newest release was 3.2.7, which has no fix. The main branch of
  Rack raises `Rack::QueryParser::IncompatibleEncodingError` there, and Rails 8.1.4 maps no such
  class to a 400.

**D2. The guard answers each `EncodingError` of the parser.**
`Encoding::CompatibilityError` is the error for a charset that is not ASCII-compatible. Rack 3.2
changes a part in ISO-2022-JP to UTF-8, and that change raises `Encoding::InvalidByteSequenceError`
for bytes that are not valid in ISO-2022-JP. Both are an `EncodingError`, and each one is an error of
the request. Each other error of the parser passes to the next middleware, which gets the same error
from Rack. So a type conflict of two params and a truncated body keep their answers. D5 holds one
exception for Rack 2.2.

**D3. The guard reads a multipart request only, for each request method.** Only a multipart part
has a charset. A body with another content type passes with no read. For a POST,
`Rack::MethodOverride` reads the params at this position already. For a PATCH, a PUT or a DELETE,
Rails reads them later, so the parse now runs before the middleware that comes after the guard. A
part of a file passes, because Rack gives no charset to the name of such a part.

**D4. The guard goes directly after `ActionDispatch::Executor`.** The default stack of Rails holds
`ActionDispatch::Executor` before `Rack::MethodOverride`. An API-only host has no
`Rack::MethodOverride`, and an insert before it raises an error at the boot of that host.

The request stops before `Rack::TempfileReaper`, so the guard closes the upload files that Rack
lists for the request.

**D5. The guard also answers the plain `ArgumentError` of Rack 2.2.** The maintainer chose it on
2026-10-05: the engine supports Rails 6.1, and Rails 6.1 and 7.0 need Rack 2. Rack 2.2 raises
`Encoding::CompatibilityError` only when the bytes of the part name are valid in the charset of the
part. For other bytes it raises a plain `ArgumentError` with the text `invalid byte sequence`. A
name of 3 bytes in UTF-16LE is an example, and so is an ASCII name in UTF-32. With no answer for
that error, those requests keep their 500 with Rack 2.2.

The param errors of Rack are subclasses of `ArgumentError`, and Rack and Rails handle them. So the
guard answers only an error whose class is `ArgumentError` itself and whose text starts with
`invalid byte sequence`. With Rack 2.2, that rule also covers a part name with broken bytes in an
ASCII-compatible charset.

CI resolves Rack 3.2 on each row. So the examples give the guard a stub of the parser that raises
the error of Rack 2.2. A probe with Rack 2.2.22 backs the decision: each probed part in UTF-16,
UTF-32 or UTF-7 gets the 400.

## Risks / Trade-offs

- A later Rack can keep the name of a part readable. The parser then raises no error for such a
  part, and the guard passes the request.
