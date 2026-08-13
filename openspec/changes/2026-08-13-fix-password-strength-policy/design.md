# Design

## D1. Length-only minimum, on the default user

`validates :password, length: { minimum: 8 }, allow_blank: true` is added beside `has_secure_password`
in `CamaleonCms::User`. Length-only is a deliberate choice (NIST 800-63B): an 8-character floor removes
the trivially-guessable passwords the finding flagged without the usability and false-security costs of
forced character classes. The maximum (72 bytes) is already validated by `has_secure_password`.

It lives on the default `User` class — which is only defined when the host has not supplied its own
`user_model` — rather than in the shared `UserMethods` concern, because `password` is a
`has_secure_password` accessor the default user is guaranteed to have; a custom user model owns its own
password policy.

## D2. allow_blank, not allow_nil

`allow_blank` skips the rule when the password is nil **or** empty. This matters on update: an admin
editing a profile submits an empty password field to mean "leave it", which `has_secure_password`
already treats as no change. `allow_nil` would still run the length check on that empty string and
reject the edit; `allow_blank` leaves it alone. On create, an empty password is caught by
`has_secure_password`'s presence validation, not this one; a short-but-present password is caught here.

## D3. Testing

`spec/models/password_strength_policy_spec.rb`: a 7-character password is invalid (fails on master), an
8-character one is valid, and updating a record without touching its password still saves. A pre-existing
`user_spec` example that created a user with a 4-character throwaway password is updated to a valid one,
since the policy now (correctly) rejects it.
