# captcha-challenge-integrity Specification

## Purpose
Pin that the captcha is a single, single-use, bounded-length challenge, so it cannot be turned into an
unauthenticated denial-of-service vector or bypassed. The `/captcha` endpoint is unauthenticated and takes
an attacker-controlled length; the answer is held in the session and checked on form submission. Without
bounds and single-use semantics, a caller could exhaust worker memory with a huge image, shrink the answer
space to a brute-forceable size, or replay/accumulate answers to pass without solving anything.
## Requirements
### Requirement: The captcha length is bounded

`cama_captcha_build` SHALL clamp the requested character count into a safe range (a lower floor and an
upper ceiling) before generating the image, and SHALL fall back to the default for a non-numeric or absent
value. An attacker-supplied `?len=` SHALL NOT be able to exhaust memory with an oversized image or shrink
the answer space below the floor.

#### Scenario: An oversized length is clamped to the ceiling

- **WHEN** `GET /captcha?len=64` is requested
- **THEN** the challenge stored for verification is at most the ceiling length (8)

#### Scenario: A tiny length is raised to the floor

- **WHEN** `GET /captcha?len=1` is requested
- **THEN** the challenge stored for verification is at least the floor length (4)

### Requirement: Only a single active captcha challenge is valid

Each captcha build SHALL replace the stored challenge rather than accumulate answers, so that only the
most recently issued (currently displayed) challenge can verify. A previously issued answer SHALL NOT
verify once a new challenge has been issued.

#### Scenario: Repeated loads keep only one active challenge

- **WHEN** `/captcha` is requested several times in a session
- **THEN** the session holds exactly one active challenge, not one per request

### Requirement: A solved captcha is single-use and a blank never matches

`cama_captcha_verified?` SHALL match the submitted value (case-insensitively) only against the single
active challenge, SHALL reject a blank submission, and SHALL consume the challenge on success so it cannot
be replayed. A legitimate submission of the current answer SHALL verify.

#### Scenario: The current answer verifies and is then consumed

- **WHEN** the answer to the active challenge is submitted
- **THEN** it verifies, and the same value submitted again does not verify

#### Scenario: A blank submission is rejected

- **WHEN** a blank captcha value is submitted
- **THEN** it does not verify, even if the stored challenge is itself blank

#### Scenario: A legitimate registrant passes with the correct current captcha

- **WHEN** a user submits the registration form with the answer to the captcha that form issued
- **THEN** the account is created

