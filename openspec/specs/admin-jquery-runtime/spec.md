# admin-jquery-runtime Specification

## Purpose
Pin the admin browser runtime contract after the jQuery 3 upgrade: which jQuery version admin
pages (and the bundled themes) run on, which jQuery UI widgets remain callable by downstream
plugins and themes versus withdrawn, and the autocomplete option contract the replacement engine
must honor.

## Requirements

### Requirement: Admin pages run jQuery 3.7.1 with an expressed dependency floor

Admin pages and the bundled themes SHALL load jQuery 3.7.1 through the `jquery3` logical asset,
and the gem SHALL declare a `jquery-rails` dependency floor of at least 4.6.1 so every host
resolves an asset that exists at the validated version. Shipped admin scripts MUST NOT call APIs
removed in jQuery 3 (jqXHR `.success`/`.error`/`.complete`, event shorthands such as element
`.load`/`.error`, the collection `.selector` property, the `ready` event form).

#### Scenario: Host resolves the admin bundle

- **WHEN** a host application bundles the gem and compiles admin assets
- **THEN** the `jquery3` asset resolves (no Sprockets file-not-found) and admin pages run
  jQuery 3.7.1

#### Scenario: A jQuery-2-only host cannot silently under-resolve

- **WHEN** a host's lockfile would pin `jquery-rails` below 4.6.1
- **THEN** dependency resolution refuses the combination instead of serving an older jQuery 3.x
  than the one the admin scripts were validated against

### Requirement: The sortable widget surface survives jQuery UI withdrawal

The admin bundle SHALL provide `$.fn.sortable` and `$.fn.disableSelection` with
jQuery-UI-compatible call semantics (options object with `handle`, `items`/`cancel`, `axis`,
`update`/`start`/`stop` callbacks receiving a `ui`-shaped argument sufficient for the surveyed
ecosystem consumers) even though the jQuery UI bundle itself is withdrawn. Ecosystem plugins that
bind only to these two members (the bundled contact-form builder, post reordering, e-commerce
attribute ordering) MUST keep working without changes.

#### Scenario: Plugin calls the shimmed sortable

- **WHEN** an admin page script calls `$(list).sortable({handle: '...', update: fn})`
- **THEN** drag reordering works and the `update` callback fires on drop with the reordered DOM
  observable, without jQuery UI being loaded

#### Scenario: Withdrawn widget is absent, not broken silently

- **WHEN** a script calls a withdrawn jQuery UI widget (for example `.draggable()` or
  `.dialog()`) without bundling jQuery UI itself
- **THEN** the call fails as an undefined member (a consumer must bundle jQuery UI); no partial
  emulation is provided

### Requirement: Admin autocomplete honors the jQuery-UI-style option contract

Admin tag-input autocompletes SHALL keep the option contract callers used under jQuery UI
autocomplete regardless of the backing engine: a function `source` is invoked with a
`{term: <string>}` request object and a response callback; a string-URL `source` is queried
per keystroke with a `term` parameter; `minLength` bounds when suggestions appear; a `select`
callback receives a `ui.item` object carrying the chosen value. Suggestions already present as
committed tags SHALL be excluded, and the uncommitted text being typed MUST NOT be written into
the form field or treated as a committed tag.

#### Scenario: Remote source queried per keystroke

- **WHEN** a caller configures `autocomplete: {source: '/suggest', minLength: 2}` and the user
  types a third character
- **THEN** the engine requests `/suggest` with a `term` parameter for the typed prefix and shows
  the returned suggestions

#### Scenario: Typing never mutates the committed value

- **WHEN** the user has typed a partial tag that is not yet committed
- **THEN** the underlying form field still holds only committed tags (an autosave serializes no
  partial text)
