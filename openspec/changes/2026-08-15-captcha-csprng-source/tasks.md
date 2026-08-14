# Tasks

## 1. Reproduce first

- [x] 1.1 `spec/lib/camaleon_cms/captcha_random_source_spec.rb`: the generator draws from
  `SecureRandom` and still yields a valid challenge string
- [x] 1.2 Confirm the CSPRNG example fails against the `Kernel#rand` version

## 2. Fix

- [x] 2.1 Replace `rand` with `SecureRandom.random_number` in `cama_rand_str`

## 3. Verification

- [x] 3.1 `bin/rubocop` — no offenses
- [x] 3.2 `bin/rspec` the new spec + the captcha parity spec — green
- [ ] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [ ] 3.4 Changelog + archive at ship time
