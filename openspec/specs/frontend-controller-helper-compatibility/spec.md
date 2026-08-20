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
