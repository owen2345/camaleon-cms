# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/admin/appearances/xhr_save_refusal_spec.rb`: a refused nav menu item
  save by XHR answers with the message and a 422 and stores nothing; a submitted form and an XHR with
  `cama_ajax_request` keep the redirect and the flash; a category save by XHR with an array meta and
  a draft save by XHR with a refused value answer with a 422. Confirm that they fail on the unfixed
  code
- [x] 1.2 Add `spec/features/admin/nav_menu_item_settings_refusal_spec.rb`: the modal shows a
  refused value and stays open, and closes on a stored value. Confirm that the first example fails on
  the unfixed script

## 2. The remedy

- [x] 2.1 Answer both rescue handlers of `CamaleonCms::AdminController` through `refuse_admin_save`
  (D1 to D5)
- [x] 2.2 Read the answer in the nav menu item settings modal: a 422 shows the refusal in the modal,
  another failure shows a generic message, the spinner comes down on each outcome (D6)
- [x] 2.3 Add `msg.save_failed` to the admin JavaScript locales that hold `msg.draft_save_failed`

## 3. Documentation

- [x] 3.1 Add the section and the table row to `docs/upgrading-to-2.9.5.md`
- [x] 3.2 Record the survey of the XHR callers in `docs/ai/ecosystem.md`
- [x] 3.3 Name the XHR answer in `docs/security/permissions.md`

## 4. Verification and release steps

- [x] 4.1 `bin/rubocop -A`, `bin/rspec` on the new specs and the adjacent ones,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
