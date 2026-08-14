# Tasks

## 1. Reproduce first

- [x] 1.1 `spec/requests/security/save_comment_robustness_spec.rb`: a bad post id and a missing
  `post_comment` must not 500
- [x] 1.2 Confirm both raise NoMethodError against the unguarded action

## 2. Fix

- [x] 2.1 Resolve the post with `&.decorate` and handle nil; default `post_comment` to `{}`; guard the
  redirect fallback

## 3. Verification

- [x] 3.1 `bin/rubocop` — no offenses
- [x] 3.2 `bin/rspec` the new spec + `spec/requests/frontend/save_comment_spec.rb` — green
- [x] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [x] 3.4 Changelog + archive at ship time
