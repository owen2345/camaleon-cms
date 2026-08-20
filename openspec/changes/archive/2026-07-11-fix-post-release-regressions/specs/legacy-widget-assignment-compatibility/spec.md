## ADDED Requirements

### Requirement: Preserve widget assignments across STI discriminator formats
The system SHALL return widget assignments stored with either the legacy
`CamaleonCms::Widget::Assigned` discriminator or the compact `Widget::Assigned` discriminator. New widget
assignments SHALL continue to use the compact discriminator.

#### Scenario: Loading a sidebar upgraded from a legacy release
- **WHEN** a sidebar has an assignment row whose `post_class` is `CamaleonCms::Widget::Assigned`
- **THEN** the sidebar SHALL return that assignment through its `assigned` association and the associated
  widget SHALL remain available for rendering

#### Scenario: Loading mixed legacy and current assignments
- **WHEN** a sidebar has assignments stored with both supported discriminator formats
- **THEN** the sidebar SHALL return all of those assignments in their configured item order

#### Scenario: Creating an assignment after the compatibility fix
- **WHEN** a widget is assigned to a sidebar after the fix is deployed
- **THEN** the assignment SHALL be stored with the compact `Widget::Assigned` discriminator
