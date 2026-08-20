## Purpose

Ensure frontend navigation rendering preserves the configured order of each menu level.

## Requirements

### Requirement: Render navigation items in configured order
The system SHALL render frontend navigation items in ascending `term_order` at every menu level. Rendering
SHALL preserve that order even when record identifiers differ from the configured order.

#### Scenario: Rendering reordered root navigation items
- **WHEN** root menu items have `term_order` values that differ from their creation order
- **THEN** the rendered menu markup SHALL list the items in ascending `term_order`

#### Scenario: Rendering reordered nested navigation items
- **WHEN** a parent menu item has child items with `term_order` values that differ from their creation order
- **THEN** the rendered nested markup SHALL list the child items in ascending `term_order`

#### Scenario: Supplying callback indices for ordered items
- **WHEN** a menu callback receives rendered root or nested items
- **THEN** each callback index SHALL reflect the item's position in configured `term_order`
