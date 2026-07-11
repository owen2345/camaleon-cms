## Why

The post-2.9.2 changes through `746a9fa9` introduced upgrade and rendering regressions that affect
existing CMS installations and plugin controllers. Existing widget assignments can disappear, navigation
menus can render in the wrong order, and controller-facing frontend helper APIs can fail at runtime.

## What Changes

- Preserve access to legacy namespaced widget-assignment records after the native STI migration.
- Render frontend navigation items in their configured `term_order`, including nested items.
- Restore the controller runtime surface for `cama_url_to_fixed` and `verify_front_visibility` used by
  frontend plugin controllers.
- Add focused regression coverage for each repaired behavior, including upgrade-compatible persisted data.

## Capabilities

### New Capabilities

- `legacy-widget-assignment-compatibility`: Upgrade-compatible retrieval and rendering of pre-STI widget assignments.
- `ordered-navigation-rendering`: Navigation rendering that honors configured item order at every menu level.
- `frontend-controller-helper-compatibility`: Stable frontend controller access to legacy helper methods required by plugins.

### Modified Capabilities

- None.

## Impact

- Affected models: `CamaleonCms::PostDefault`, `CamaleonCms::Widget::Assigned`,
  `CamaleonCms::Widget::Sidebar`, and `CamaleonCms::Widget::Main`.
- Affected rendering: `CamaleonCms::Frontend::NavMenuHelper`.
- Affected controller/plugin API: `CamaleonCms::FrontendController` and inheriting plugin frontend controllers.
- Affected tests: model, helper, and controller compatibility specs.
