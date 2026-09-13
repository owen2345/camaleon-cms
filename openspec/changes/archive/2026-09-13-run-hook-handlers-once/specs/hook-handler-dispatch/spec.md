## Purpose

A registered hook handler runs exactly once per dispatch, after its plugin's helpers are included,
and any failure reaches the caller unchanged, including the `NoMethodError` of a handler that
nothing defines.

## ADDED Requirements

### Requirement: A handler runs once per dispatch

When a hook is dispatched, each registered handler of each enabled plugin or theme SHALL be run at
most once. A failure raised by a handler SHALL propagate to the caller unchanged; the dispatcher
SHALL NOT rescue it and run the handler again.

#### Scenario: A handler fails after a side effect

- **WHEN** a handler performs a side effect and then raises
- **THEN** the side effect SHALL have happened once and the caller SHALL receive that error

#### Scenario: A handler's own code raises NoMethodError naming it

- **WHEN** a handler performs a side effect and its own code then raises a `NoMethodError` naming the
  handler
- **THEN** the side effect SHALL have happened once and the caller SHALL receive that `NoMethodError`

### Requirement: A plugin's helpers are included before its handlers run

Before running a plugin's handlers for a hook, the dispatcher SHALL include each helper module the
plugin declares that the dispatching object does not already include, whether or not the object
already answers a handler's name, and SHALL NOT include a module the object already includes again.

#### Scenario: A helper not yet included

- **WHEN** a plugin declares a helper module defining the handler and the module is not yet
  included into the dispatching object
- **THEN** the module SHALL be included and the handler SHALL run once

#### Scenario: A handler named like a method the object already answers

- **WHEN** a plugin's helper defines a handler whose name the dispatching object already answers
  with a method of its own
- **THEN** the helper's method SHALL be the one that runs

#### Scenario: Helpers loaded again

- **WHEN** a plugin's helpers are loaded into an object that already includes them
- **THEN** no module SHALL be included again and no module's `included` hook SHALL run again

### Requirement: A handler is called without being looked up first

The dispatcher SHALL call each handler without first checking whether the dispatching object
defines it, on the controller and the view dispatch paths alike. A handler that nothing defines
SHALL raise `NoMethodError` to the caller, so a hook that gates content fails closed.

#### Scenario: A handler no helper defines

- **WHEN** a plugin registers a handler that neither its helper modules nor the dispatching object
  define
- **THEN** the caller SHALL receive a `NoMethodError` naming the handler, and the hook's later
  handlers SHALL NOT run

#### Scenario: A handler answered through method_missing

- **WHEN** a plugin's helper answers the handler through `method_missing` without declaring
  `respond_to_missing?`
- **THEN** the handler SHALL run once
