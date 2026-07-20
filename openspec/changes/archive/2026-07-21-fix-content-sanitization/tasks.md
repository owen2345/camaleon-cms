## 1. Remove normalize_attrs from plain-text fields

- [x] 1.1 Remove `normalize_attrs(:value)` from `app/models/camaleon_cms/meta.rb`
- [x] 1.2 Remove `normalize_attrs(:first_name, :last_name, :username)` from `app/models/concerns/camaleon_cms/user_methods.rb`
- [x] 1.3 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/user_role.rb`
- [x] 1.4 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/site.rb`
- [x] 1.5 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/category.rb`
- [x] 1.6 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/post_type.rb`
- [x] 1.7 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/post_tag.rb`
- [x] 1.8 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/plugin.rb`
- [x] 1.9 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/theme.rb`
- [x] 1.10 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/nav_menu.rb`
- [x] 1.11 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/nav_menu_item.rb`
- [x] 1.12 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/widget/main.rb`
- [x] 1.13 Remove `normalize_attrs(:name)` from `app/models/camaleon_cms/widget/sidebar.rb`

## 2. Add meta email_from preservation test

- [x] 2.1 Create spec verifying email addresses with angle brackets survive round-trip through `set_option`/`get_option`
- [x] 2.2 Create spec verifying other angle-bracket content in Meta#value is preserved
- [x] 2.3 Run spec to confirm it passes after removal of normalize_attrs from Meta

## 3. Add allow_unfiltered_html permission key

- [x] 3.1 Add `allow_unfiltered_html` key to `UserRole::ROLES[:post_type]` in `app/models/camaleon_cms/user_role.rb`
- [x] 3.2 Add `can :post_unfiltered_html, CamaleonCms::PostType` rule to `Ability#initialize` in `app/models/camaleon_cms/ability.rb`
- [x] 3.3 Update `SiteDefaultSettings#set_default_user_roles` admin role to include `allow_unfiltered_html` on all post types

## 4. Add Post#content sanitization with role-based logic

- [x] 4.1 Add `extend CamaleonCms::NormalizeAttrs` and `normalize_attrs(:content)` to `app/models/camaleon_cms/post.rb`
- [x] 4.2 Modify `normalize_attrs` concern to accept an optional `:unless` block/proc parameter that gates sanitization
- [x] 4.3 Pass condition for Post: skip sanitization when `current_user` has `post_unfiltered_html` permission
- [x] 4.4 Default Rails sanitizer allowlist strips dangerous tags (script, iframe, event handlers) while preserving safe HTML

## 5. Tests for post content sanitization

- [x] 5.1 Create spec verifying contributor (no `allow_unfiltered_html`) has `<script>` stripped from post content
- [x] 5.2 Create spec verifying contributor has SVG `onbegin` handler stripped
- [x] 5.3 Create spec verifying contributor has `javascript:` URLs stripped
- [x] 5.4 Create spec verifying contributor has `onerror` event handlers stripped
- [x] 5.5 Create spec verifying admin (with `allow_unfiltered_html`) preserves `<iframe>` and `<script>`
- [x] 5.6 Create spec verifying editor with `allow_unfiltered_html` permission preserves raw HTML
- [x] 5.7 Create spec verifying sanitization applies when `CurrentRequest.user` is nil (background jobs)
- [x] 5.8 Run all specs to confirm XSS payloads are blocked and safe HTML is preserved

## 6. Verification and security review

- [x] 6.1 Run full test suite: `bin/rspec`
- [x] 6.2 Run linter: `bin/rubocop -A`
- [x] 6.3 Run security scanner: `bin/brakeman --no-pager`
- [x] 6.4 Verify Rails autoloading: `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 6.5 Manually verify existing normalize_attrs shared spec still passes for PostComment (unchanged behavior)
- [x] 6.6 Manually verify email_from setting survives save in admin panel
