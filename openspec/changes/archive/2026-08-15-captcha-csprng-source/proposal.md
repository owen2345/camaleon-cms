# Draw the captcha challenge from a CSPRNG (Low)

## Why

`cama_rand_str` — which builds the captcha challenge string — used `Kernel#rand`, a Mersenne-Twister
PRNG. Its internal state is recoverable from a modest run of observed outputs, so an attacker who
collects a few challenges could predict subsequent ones, weakening the captcha that H1–H4 hardened.
Audit Low.

### Triage verdict: legit

`captcha_image_generation.rb` used `rand(...)`. Reproduced in
`spec/lib/camaleon_cms/captcha_random_source_spec.rb`: the generator did not touch `SecureRandom`
before the fix.

## What Changes

- `cama_rand_str` draws each character index from `SecureRandom.random_number` instead of
  `Kernel#rand`. Output shape (length, alphabet) is unchanged.

## Notes for upgraders

- None.
