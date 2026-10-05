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

The maintainer chose D1 and D5 on 2026-10-05. "The guard" is `CamaleonCms::MultipartEncodingGuard`.

**D1. A Rack middleware of Camaleon parses the params first.** The guard parses the params of a
multipart request with `Rack::Request#POST`, the call that `Rack::MethodOverride` and Rails use.
Rack keeps the result in the env, so nothing parses the body twice. The guard answers an
`EncodingError` of that call with a 400 and the body `Bad Request`. It writes one line to
`rack.errors`, as `Rack::MethodOverride` does for the errors that it handles. Rejected:

- An entry in `config.action_dispatch.rescue_responses`. It does not cover a POST, and the other
  methods keep the failsafe 500, because `ShowExceptions` reads the params again.
- A newer Rack. The newest release on 2026-10-05, 3.2.7, has no fix. The main branch of Rack raises
  `Rack::QueryParser::IncompatibleEncodingError` there, and Rails 8.1.4 maps no such class to a
  400.

**D2. The guard answers each `EncodingError` of the parser.** `Encoding::CompatibilityError` is the
error for a charset that is not ASCII-compatible. Rack 3.2 converts a part in ISO-2022-JP to UTF-8,
which raises `Encoding::InvalidByteSequenceError` for invalid bytes. Both are errors of the
request. Each other error of the parser passes to the next middleware, which gets the same error
from Rack. So a type conflict of two params and a truncated body keep their answers. D5 has one
exception for Rack 2.2.

**D3. The guard parses a multipart request only, for each request method.** Only a multipart part
has a charset, so a body with another content type passes with no read. For a POST,
`Rack::MethodOverride` already parses the params soon after this position, in a stack that has it.
For each other method, and for a POST in an API-only host, Rails parses them later, so the parse
now runs before the middleware that comes after the guard. A file part passes, because Rack gives
no charset to its name.

**D4. The guard goes directly after `ActionDispatch::Executor`.** The default stack of Rails has
that middleware before `Rack::MethodOverride`. An API-only host has no `Rack::MethodOverride`, and
an insert before it raises an error at the boot of that host. The request stops before
`Rack::TempfileReaper`, so the guard removes the temporary files that Rack recorded in
`rack.tempfiles`. Rack records them after its multipart parser ends. When that parser raises the
error (a part in ISO-2022-JP with Rack 3.2, each case with Rack 2.2), the env has no such files,
and Ruby removes them at garbage collection. The same occurred before this change.

**D5. The guard also answers the plain `ArgumentError` of Rack 2.2.** Camaleon supports Rails 6.1,
and Rails 6.1 and 7.0 need Rack 2. Rack 2.2 raises `Encoding::CompatibilityError` only when the
bytes of the part name are valid in the charset of the part. For other bytes it raises a plain
`ArgumentError` with the message `invalid byte sequence`. A name of 3 bytes in UTF-16LE is an
example, and so is an ASCII name in UTF-32. Without this decision, those requests keep their 500
with Rack 2.2.

The param errors of Rack are subclasses of `ArgumentError`, and Rack and Rails handle them. So the
guard answers only an error whose class is `ArgumentError` itself and whose message starts with
`invalid byte sequence`. With Rack 2.2, that rule also covers a part name with invalid bytes in an
ASCII-compatible charset.

CI runs Rack 3.2 on each row, so the examples stub the parser. A probe with Rack 2.2.22 backs the
decision: each probed part in UTF-16, UTF-32 or UTF-7 gets the 400.

## Risks / Trade-offs

- A later Rack can keep the name of a part in UTF-8. The parser then raises no error for such a
  part, and the guard passes the request.
