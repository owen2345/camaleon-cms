## ADDED Requirements

### Requirement: A multipart request that Rack cannot parse for its encoding gets a 400

A part of a multipart request can name a charset, and Rack gives that charset to the name of the
part too. The param parser of Rack then raises an encoding error for a part in a charset that is
not ASCII-compatible (UTF-16, UTF-32, UTF-7), and for a part in ISO-2022-JP with invalid bytes.

The system SHALL answer such a request with a 400, for each request method. No controller action
SHALL start, and the request SHALL store nothing. The system SHALL remove the temporary files that
Rack recorded for the uploads of that request. Rack records none when its multipart parser raises
the error: a part in ISO-2022-JP with invalid bytes, and each case with Rack 2.2. Ruby then removes
the files at garbage collection.

`CamaleonCms::MultipartEncodingGuard` (the guard) gives that answer:

- It SHALL parse the params of a multipart request only, with the parser of Rack.
- It SHALL also answer the plain `ArgumentError` of Rack 2.2 with a 400. Rack 2.2 raises that error
  when the bytes of the part name are invalid in the charset of the part.
- It SHALL NOT answer another error of the parser. A param error of Rack that is a subclass of
  `ArgumentError` SHALL pass. Rack and Rails handle such an error as before.
- A file part SHALL pass, because Rack gives no charset to the name of a file part.

#### Scenario: A POST with a part in UTF-16 gets a 400

- **WHEN** a multipart POST to an admin save has a part with `charset=UTF-16LE`
- **THEN** the response is a 400, and the save stores nothing

#### Scenario: A PATCH with a part in UTF-16 gets a 400

- **WHEN** a multipart PATCH, or a multipart POST with `_method=patch`, has a part with
  `charset=UTF-16LE`
- **THEN** the response is a 400, and the stored values of the record are unchanged

#### Scenario: A part in an ASCII-compatible charset reaches the controller

- **WHEN** a multipart request has a part with `charset=ISO-8859-1`
- **THEN** the controller saves the request

#### Scenario: The plain ArgumentError of Rack 2.2 gets a 400

- **WHEN** the param parser raises an error of the class `ArgumentError` itself, with a message
  that starts with `invalid byte sequence`, for a multipart request
- **THEN** the response is a 400, and the next middleware does not get the request

#### Scenario: Another error of the parser stays with Rack and Rails

- **WHEN** a multipart request has two parts whose names give one param two types
- **THEN** the guard gives the request to the next middleware, which gets the same error

### Requirement: The guard is installed before Rack::MethodOverride on each host

The system SHALL install `CamaleonCms::MultipartEncodingGuard` directly after
`ActionDispatch::Executor` in the middleware stack. That position is before `Rack::MethodOverride`,
which parses the params of a POST. The boot of the application SHALL NOT depend on
`Rack::MethodOverride`, because an API-only host has no such middleware.

#### Scenario: The guard precedes Rack::MethodOverride

- **WHEN** the host application boots
- **THEN** `CamaleonCms::MultipartEncodingGuard` sits directly after `ActionDispatch::Executor` and
  before `Rack::MethodOverride`
