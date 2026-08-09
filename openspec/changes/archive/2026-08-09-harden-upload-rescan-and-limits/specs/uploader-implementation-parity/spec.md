## MODIFIED Requirements

### Requirement: Each entry point keeps its own upload message pipeline

The system SHALL render user-facing upload error messages through a seam that each entry point
supplies. `CamaleonCms::UploaderHelper` translates via `ct` and `cama_t`. `CamaleonCms::RuntimeUploaderConcern`
SHALL translate through `ct` when its host responds to `ct` — which is the case for the media
controllers, where `ct` was restored to the controller chain — so the `on_translation` hook that
lets plugins override message text runs on the controller upload path too; when the host does not
respond to `ct` (a non-controller includer), it SHALL fall back to `I18n`. The default (no hook)
translation MUST be identical on both paths.

#### Scenario: A plugin can override an upload message on the helper path

- **WHEN** a plugin registers an `on_translation` hook that replaces the file-size-exceeded text
- **AND** an upload is rejected for exceeding the size limit through `CamaleonCms::UploaderHelper`
- **THEN** the returned error contains the plugin's text

#### Scenario: A plugin can override an upload message on the controller path

- **WHEN** a plugin registers an `on_translation` hook that replaces the file-size-exceeded text
- **AND** an upload is rejected through a host that includes `CamaleonCms::RuntimeUploaderConcern`
  and responds to `ct`
- **THEN** the returned error contains the plugin's text

#### Scenario: The controller path translates without the hook

- **WHEN** an upload is rejected for exceeding the size limit through a
  `CamaleonCms::RuntimeUploaderConcern` host with no `on_translation` hook registered
- **THEN** the returned error contains the `I18n` translation of the message

#### Scenario: The concern falls back to I18n without ct

- **WHEN** an upload message is rendered through a `CamaleonCms::RuntimeUploaderConcern` host that
  does not respond to `ct`
- **THEN** the message is the `I18n` translation
- **AND** rendering does not require `ct` to be defined

#### Scenario: Both paths report the same limit

- **WHEN** the same size limit is exceeded through either entry point with no `on_translation`
  hook registered
- **THEN** both errors state the limit in the same human-readable form
