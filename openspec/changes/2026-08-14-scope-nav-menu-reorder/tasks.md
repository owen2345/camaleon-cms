# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/security/cross_site_nav_menu_reorder_spec.rb`: posting another site's
  `nav_menu_id` to `reorder_items` must not move the item; same-site reordering still works
- [x] 1.2 Confirm the cross-site move succeeds against the unfixed controller

## 2. Fix

- [x] 2.1 Resolve the root destination through `current_site.nav_menus.find(params[:nav_menu_id])`

## 3. Verification

- [x] 3.1 `bin/rubocop` on the touched files — no offenses
- [x] 3.2 `bin/rspec` on the reproduction spec and `spec/features/admin/menus_spec.rb` — green
- [ ] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [ ] 3.4 Changelog + archive at ship time
