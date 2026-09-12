## Purpose

A registered hook handler runs exactly once per dispatch, with its plugin's helpers loaded on
demand, and a failure inside it reaches the caller unchanged; a handler that no helper defines is
skipped with a warning rather than retried or raised.

## ADDED Requirements

### Requirement: A handler runs once per dispatch

When a hook is dispatched, each registered handler of each enabled plugin or theme SHALL be run at
most once. A failure raised by a handler SHALL propagate to the caller unchanged; the dispatcher
SHALL NOT rescue it and run the handler again.

#### Scenario: A handler fails after a side effect

- **WHEN** a handler performs a side effect and then raises
- **THEN** the side effect SHALL have happened once and the caller SHALL receive that error

### Requirement: A handler's helper is loaded before its single run

When a registered handler is not yet defined on the dispatching object, the dispatcher SHALL
include the plugin's declared helper modules before running it, so the handler still runs exactly
once.

#### Scenario: A helper not yet included

- **WHEN** a plugin declares a helper module defining the handler and the module is not yet
  included into the dispatching object
- **THEN** the module SHALL be included and the handler SHALL run once

### Requirement: An undefined handler is skipped with a warning

When a registered handler is still undefined after the plugin's helpers are loaded, the dispatcher
SHALL skip it and log a warning naming the hook, the plugin and the handler, on the controller and
the view dispatch paths alike, and the remaining handlers SHALL still run.

#### Scenario: A handler no helper defines

- **WHEN** a plugin registers a handler that none of its helper modules defines
- **THEN** the dispatch SHALL complete without raising, a warning SHALL be logged, and the other
  handlers of the hook SHALL run
