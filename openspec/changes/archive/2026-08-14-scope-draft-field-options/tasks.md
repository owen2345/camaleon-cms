# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/security/draft_field_options_scope_spec.rb`: a draft create/update
  carrying a registered slug and an unregistered one must keep the registered and drop the foreign
- [x] 1.2 Confirm the unregistered slug persists against the unfixed controller

## 2. Fix

- [x] 2.1 Filter `field_options` through `cama_permitted_field_options('PostType_Post')` in
  `Posts::DraftsController#create` and `#update`

## 3. Verification

- [x] 3.1 `bin/rubocop` on the touched files — no offenses
- [x] 3.2 `bin/rspec` on the reproduction spec and `spec/requests/security/draft_authorization_spec.rb`
  — green
- [x] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [x] 3.4 Changelog + archive at ship time
