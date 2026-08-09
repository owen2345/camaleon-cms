## Purpose

Define how `Admin::MediaController#crop` responds when the underlying upload fails, so a failure is
visible to the caller and never corrupts the saved avatar.

## ADDED Requirements

### Requirement: The crop action surfaces an upload failure instead of an empty success

When `upload_file` returns an error (a result carrying `:error` and no `url`), the crop action SHALL
render the sanitized error message as its response body rather than an empty body, so a consumer of
the endpoint (the avatar flow) cannot store an empty string as the cropped URL.

#### Scenario: A failed crop upload returns the error message

- **WHEN** `crop` is invoked and `upload_file` returns `{ error: <message> }`
- **THEN** the response body is the sanitized error message, not empty

### Requirement: A failed crop does not overwrite the saved avatar

When the crop upload fails, the action SHALL NOT write the user's `avatar` meta, so a failed crop
leaves any previously saved avatar intact rather than replacing it with a nil URL.

#### Scenario: The saved avatar is untouched on a failed crop

- **WHEN** `crop` is invoked with a `saved_avatar` user id and `upload_file` returns an error
- **THEN** that user's `avatar` meta is unchanged
