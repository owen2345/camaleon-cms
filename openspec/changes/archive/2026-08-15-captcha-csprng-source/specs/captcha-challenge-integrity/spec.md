# captcha-challenge-integrity

## ADDED Requirements

### Requirement: The captcha challenge is drawn from a CSPRNG

The captcha challenge string SHALL be generated from a cryptographically secure random source
(`SecureRandom`), not a predictable PRNG such as `Kernel#rand`, so that observing past challenges
does not let an attacker anticipate future ones.

#### Scenario: Challenge generation uses a CSPRNG

- **WHEN** a captcha challenge string is generated
- **THEN** its characters are drawn from `SecureRandom`, and the string keeps its required length and
  alphabet
