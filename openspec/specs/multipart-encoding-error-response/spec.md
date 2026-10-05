# multipart-encoding-error-response Specification

## Purpose
Answer a multipart request that the param parser of Rack cannot read for its encoding with a 400.
Before, the server answered that request with a 500.

## Requirements

### Requirement: A multipart request with an encoding error of the param parser gets a 400

The system SHALL answer a multipart request with a 400 when the param parser of Rack raises an
encoding error for a part. With Rack 3, a part in a charset that is not ASCII-compatible (UTF-16,
UTF-32, UTF-7) raises that error. So does a part in ISO-2022-JP with bytes that are not valid in
that charset. The answer MUST be the same for each request method. No controller action SHALL start,
and the request SHALL store nothing. The system SHALL close the upload files that Rack lists for
that request.

`CamaleonCms::MultipartEncodingGuard` gives that answer. It SHALL read the params of a multipart
request only, with the parser of Rack. It SHALL NOT answer another error of the parser: Rack and
Rails handle that error as before. The next paragraph holds one exception. A part of a file SHALL
pass, because Rack does not read its text.

Rack 2.2 raises a plain `ArgumentError` when the bytes of the part name are not valid in the charset
of the part. The guard SHALL answer that error with a 400 too. A param error of Rack that is a
subclass of `ArgumentError` SHALL pass.

#### Scenario: A POST with a part in UTF-16 gets a 400

- **WHEN** a multipart POST to an admin save holds a part with `charset=UTF-16LE`
- **THEN** the response is a 400, and the save stores nothing

#### Scenario: A PATCH with a part in UTF-16 gets a 400

- **WHEN** a multipart PATCH, or a multipart POST with `_method=patch`, holds a part with
  `charset=UTF-16LE`
- **THEN** the response is a 400, and the stored values of the record are unchanged

#### Scenario: A part in an ASCII-compatible charset reaches the controller

- **WHEN** a multipart request holds a part with `charset=ISO-8859-1`
- **THEN** the controller saves the request

#### Scenario: The plain ArgumentError of Rack 2.2 gets a 400

- **WHEN** the param parser raises an error of the class `ArgumentError` itself, with a text that
  starts with `invalid byte sequence`, for a multipart request
- **THEN** the response is a 400, and the next middleware does not get the request

#### Scenario: Another error of the parser stays with Rack and Rails

- **WHEN** a multipart request holds two parts whose names give one param two types
- **THEN** the guard gives the request to the next middleware, which gets the same error

### Requirement: The guard is installed before Rack::MethodOverride on each host

The system SHALL install `CamaleonCms::MultipartEncodingGuard` directly after
`ActionDispatch::Executor` in the middleware stack. That position is before `Rack::MethodOverride`,
which reads the params of a POST. Application boot SHALL NOT depend on `Rack::MethodOverride`: an
API-only host has no such middleware.

#### Scenario: The guard precedes Rack::MethodOverride

- **WHEN** the host application boots
- **THEN** `CamaleonCms::MultipartEncodingGuard` sits directly after `ActionDispatch::Executor` and
  before `Rack::MethodOverride`
