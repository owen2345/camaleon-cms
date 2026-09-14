## Purpose

Maintain the frontend controller helper API relied on by inheriting plugin controllers.

## Requirements

### Requirement: Preserve frontend helper methods on frontend controllers
The system SHALL expose `cama_url_to_fixed` and `verify_front_visibility` on `FrontendController` and on
frontend controllers that inherit from it.

#### Scenario: Calling a restored URL helper from a frontend controller
- **WHEN** a frontend controller action calls `cama_url_to_fixed`
- **THEN** the call SHALL execute without a `NoMethodError`

#### Scenario: Calling a restored visibility helper from a plugin controller
- **WHEN** a plugin frontend controller inheriting from `FrontendController` calls
  `verify_front_visibility`
- **THEN** the call SHALL execute without a `NoMethodError`

### Requirement: CamaleonHelper methods are reachable in controller context

The system SHALL include `CamaleonCms::CamaleonHelper` in `CamaleonCms::CamaleonController`, so
its methods (`ct`, `cama_t`, `cama_cache_fetch`, `cama_edit_link`, `cama_sitemap_cats_generator`,
`cama_pluralize_text`, `cama_is_admin_request?`) are callable from `CamaleonController` and every
subclass — frontend, admin, and plugin controllers — not only from views. Plugin hook functions
execute on the controller instance and rely on this surface.

#### Scenario: Frontend search renders without a helper error

- **WHEN** a visitor requests `GET /search`
- **THEN** the action's `breadcrumb_add(ct('search'))` call executes without `NoMethodError`
- **AND** the search results page renders with HTTP 200

#### Scenario: Plugin code resolves its plugin model from a controller

- **WHEN** plugin code running on a controller (an action or a hook function) calls
  `current_plugin`
- **THEN** the underlying `cama_cache_fetch` call executes without `NoMethodError`
- **AND** the plugin model for the current site is returned

### Requirement: cama_t resolves its English fallback with the caller's lookup options

`cama_t(key, options)` SHALL look the English fallback up with the lookup options the caller passed (`scope`, `separator`, `raise`, `throw`) and without the interpolation values, so the fallback is the same translation the caller named and is interpolated exactly once with the caller's values. The helper SHALL NOT modify the options hash the caller passed.

#### Scenario: A scoped key falls back to the scoped English text

- **WHEN** the current locale lacks a key and `cama_t` is called with `scope:` and an interpolation value
- **THEN** the result is the English translation under that scope, interpolated with the value

#### Scenario: A missing key with raise: true raises

- **WHEN** `cama_t` is called with `raise: true` for a key missing in every locale
- **THEN** it raises the missing-translation error

#### Scenario: An interpolation value carrying a placeholder token is inserted verbatim

- **WHEN** the current locale lacks a key and `cama_t` is called with a value containing `%{x}`
- **THEN** the result contains that value verbatim and nothing raises

#### Scenario: The caller's options are left untouched

- **WHEN** the same options hash is passed to two `cama_t` calls for different keys
- **THEN** the second call resolves its own English fallback, not the first call's
