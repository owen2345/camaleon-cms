# Proposal: admin-jquery3-runtime-surface

## Why

PR #1274 moves the admin (and the bundled themes) from jQuery 2.2.4 to jQuery 3.7.1 and removes
the bundled jQuery UI, re-providing only the two widgets ecosystem plugins actually bind to via a
SortableJS-backed shim. That is a durable, ecosystem-facing runtime contract — which jQuery runs
on admin pages, which `$.fn` widgets downstream plugins may still call, and which are withdrawn —
and today no capability spec records it. This change writes the contract down; the implementation
already exists on the branch.

## What Changes

- Admin pages and the bundled themes load jQuery 3.7.1 via the `jquery3` Sprockets asset; the
  gemspec floors `jquery-rails >= 4.6.1` so every host resolves an asset that actually exists at
  the validated version.
- **BREAKING** (already recorded in CHANGELOG): the jQuery UI bundle is withdrawn from the admin.
  `$.fn.sortable` and `$.fn.disableSelection` remain available through a SortableJS-backed
  compatibility shim; all other jQuery UI widgets (`draggable`, `droppable`, `resizable`,
  `dialog`, `datepicker`, `autocomplete`, …) are no longer provided — a consumer must bundle
  jQuery UI itself.
- Admin autocomplete UIs (tag editor, tagsInput) run on Awesomplete while preserving the
  jQuery-UI-style option contract (`source`/`{term:}` remote querying, `minLength`, `select`
  with `ui.item`).
- No new code in this change: spec-only documentation of behavior shipped on
  `feature/jquery-3-upgrade`.

## Capabilities

### New Capabilities

- `admin-jquery-runtime`: the admin browser runtime contract after the jQuery 3 upgrade — the
  jQuery version and its dependency floor, the preserved-vs-withdrawn jQuery UI widget surface,
  the SortableJS shim semantics, and the Awesomplete-backed autocomplete option contract.

### Modified Capabilities

_None — the bound-API inventory in `ecosystem-plugin-bindings` and the 2.9.2-era view/helper
contracts in `runtime-compat-surfaces` are unchanged; this is a new, asset-runtime surface._

## Impact

- Affected code (already merged into the branch): admin/theme Sprockets manifests (`jquery3`),
  `camaleon_cms.gemspec` (`jquery-rails >= 4.6.1`), the SortableJS shim asset, the vendored
  Awesomplete/SortableJS sources, the tag-editor/tagsInput adapters.
- Downstream: plugins/themes calling the withdrawn widgets must bundle jQuery UI (surveyed
  casualties and the shim-covered consumers are listed in the CHANGELOG breaking-change entry).
- Specs: feature specs on the branch already exercise the shim and the autocomplete contract.
