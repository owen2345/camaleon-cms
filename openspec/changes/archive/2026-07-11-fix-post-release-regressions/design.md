## Context

The changes merged after 2.9.2 introduced three regressions in otherwise independent areas:

- Native STI now stores compact class names in `posts.post_class`, while existing widget assignments use
  the former fully qualified discriminator.
- The frontend menu renderer replaced ordered relation iteration with Active Record batch iteration.
- The helper-concern refactor removed a helper module from `FrontendController`, changing the API inherited
  by plugin frontend controllers.

The fixes must preserve data and APIs for installations upgrading from releases that predate the affected
changes. No new dependencies or schema changes are required.

## Goals / Non-Goals

**Goals:**

- Read legacy and current widget-assignment discriminators without mutating upgrade data.
- Preserve configured menu ordering at every rendered menu level.
- Restore the frontend controller helper methods previously available to plugin controllers.
- Cover each regression with behavioral specs that would fail with the regressed implementation.

**Non-Goals:**

- Convert every historical STI discriminator or redesign the broader STI model hierarchy.
- Optimize menu rendering for arbitrarily large menus at the expense of configured ordering.
- Expand the frontend controller API beyond the two helper methods lost by the refactor.
- Change the user-role form linked in the request; it is outside these regressions.

## Decisions

### Read both widget-assignment discriminator formats

`Widget::Assigned` will recognize both the compact native-STI discriminator and the legacy
`CamaleonCms::Widget::Assigned` discriminator when Rails builds its STI type condition. New records will
continue to use the compact discriminator.

This avoids a data migration that could be expensive, irreversible during a rollback, and incomplete for
installations upgraded without running an optional task. A one-time data migration was considered but
rejected because query compatibility is sufficient and safe for existing records.

### Iterate rendered menu relations in their declared order

The menu renderer will use normal relation iteration for ordered root and child relations instead of
`find_each`. `find_each` deliberately replaces scoped ordering with primary-key batching, which violates
the menu contract.

An ordered cursor-based batch implementation was considered but rejected: menus are presentation data,
their configured order is essential, and a simpler ordered iteration matches pre-regression behavior.

### Restore the controller-safe frontend helper inclusion

`FrontendController` will regain the frontend application helper inclusion so inheriting plugin controllers
again receive `cama_url_to_fixed` and `verify_front_visibility`.

Extracting only the two methods into a new concern was considered but rejected because it creates another
runtime boundary without reducing risk. Restoring the established inclusion preserves the prior public
controller API with the smallest compatibility change.

## Risks / Trade-offs

- [Legacy STI values remain in the database] -> The compatibility type condition supports them alongside
  canonical values, so upgrades and rollbacks continue to read the same assignments.
- [Ordered menu iteration loads a full menu level] -> Menu levels are rendered presentation collections;
  correctness and existing behavior take priority over batch throughput.
- [Helper inclusion exposes the existing helper surface] -> The module was already included by
  `FrontendController` before the refactor, so this restores rather than expands a documented compatibility
  surface.
