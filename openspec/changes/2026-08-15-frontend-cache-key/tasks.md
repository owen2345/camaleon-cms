# Tasks

## 1. Reproduce first

- [x] 1.1 `spec/apps/plugins/front_cache/cache_key_integrity_spec.rb`: URLs differing only in
  separators get distinct keys; an invalid path pattern does not raise
- [x] 1.2 Confirm the collision and the RegexpError against the unfixed helper

## 2. Fix

- [x] 2.1 Key the cache on `Digest::SHA256.hexdigest(uri)`; memoize + rescue the path-pattern regexes

## 3. Verification

- [x] 3.1 `bin/rubocop` — no offenses
- [x] 3.2 `bin/rspec` the new spec + the existing front_cache specs — green
- [ ] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [ ] 3.4 Changelog + archive at ship time
