## 1. Restore widget assignment upgrade compatibility

- [x] 1.1 Add model coverage for legacy and compact `Widget::Assigned` `post_class` values, mixed
  sidebar assignments, and canonical writes for newly created assignments.
- [x] 1.2 Extend `Widget::Assigned` STI type compatibility so its associations read both supported
  discriminator formats without changing persisted legacy rows.

## 2. Restore configured navigation ordering

- [x] 2.1 Add helper coverage with root and nested items whose `term_order` differs from creation order,
  including callback index assertions.
- [x] 2.2 Replace unordered batch iteration in `cama_menu_draw_items` with ordered relation iteration.

## 3. Restore frontend controller helper compatibility

- [x] 3.1 Add controller compatibility coverage for `cama_url_to_fixed` and `verify_front_visibility` on
  `FrontendController` and an inheriting plugin-style frontend controller.
- [x] 3.2 Restore the frontend application helper to the frontend controller runtime surface.

## 4. Verify the regression fixes

- [x] 4.1 Run the targeted model, frontend helper, and controller specs covering the three regressions.
- [x] 4.2 Run `(cd spec/dummy && bin/rails zeitwerk:check)`, `bin/rubocop`, and `bin/rspec`.
