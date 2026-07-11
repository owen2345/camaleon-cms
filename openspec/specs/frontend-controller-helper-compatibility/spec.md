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
