## Purpose

Define the parity requirements for the two uploader entry points: `CamaleonCms::RuntimeUploaderConcern`, reached by controllers through the runtime concern chain, and `CamaleonCms::UploaderHelper`, included into views, ActiveJobs, and standalone objects. Both entry points MUST draw their behavior from a single shared implementation under `lib/camaleon_cms/`, so that upload behavior cannot drift between them, while a message seam lets each keep its own translation pipeline and the helper stays usable without a request context.
## Requirements
### Requirement: Uploader behavior is defined once and shared by both entry points

The system SHALL define each uploader method that both `CamaleonCms::RuntimeUploaderConcern` and `CamaleonCms::UploaderHelper` provide exactly once, in a module under `lib/camaleon_cms/` that both include, so that a change to upload behavior cannot land in one entry point and not the other.

#### Scenario: Shared methods are not redefined by either host module

- **WHEN** the public and private uploader methods common to both entry points are looked up
- **THEN** neither `CamaleonCms::RuntimeUploaderConcern` nor `CamaleonCms::UploaderHelper` defines them directly
- **AND** each resolves to the same shared module for both entry points

#### Scenario: Entry-point-specific code stays with its entry point

- **WHEN** `CamaleonCms::RuntimeUploaderConcern` is inspected
- **THEN** it still defines `cama_upload_url_error`, which the media controller depends on and which has no counterpart in `CamaleonCms::UploaderHelper`

### Requirement: Both entry points expose the same uploader method surface

The system SHALL make the same public uploader methods available through `CamaleonCms::UploaderHelper` and through `CamaleonCms::RuntimeUploaderConcern`, so that host applications, plugins, and themes including either one keep the API they have today.

#### Scenario: Controller-side surface is unchanged

- **WHEN** an object of a class including `CamaleonCms::RuntimeStateConcern` is queried
- **THEN** it responds to `upload_file`, `cama_tmp_upload`, `cama_uploader`, `cama_uploader_generate_thumbnail`, `uploader_verify_name`, `cama_file_path_to_url`, `cama_url_to_file_path`, `cama_crop_image`, `cama_resize_and_crop`, `cama_resize_upload`, `slugify`, and `slugify_folder`

#### Scenario: Helper-side surface is unchanged

- **WHEN** an object of a class including `CamaleonCms::UploaderHelper` is queried
- **THEN** it responds to the same set of public uploader methods

#### Scenario: Method visibility is preserved

- **WHEN** the uploader methods that were private before the extraction are queried through either entry point
- **THEN** they remain private
- **AND** the methods that were public remain public

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

### Requirement: The helper entry point works without a request context

The system SHALL keep `CamaleonCms::UploaderHelper` usable by objects that have no controller request — including the ActiveJob usage documented in `config/initializers/custom_initializers.rb` — by ensuring shared uploader code never reads request parameters.

#### Scenario: Staging a data: upload outside a controller

- **WHEN** an object that includes `CamaleonCms::UploaderHelper` and defines `current_site`, but has no `params`, calls `cama_tmp_upload` with a `data:` URI and a `:name` argument
- **THEN** the upload is staged
- **AND** no `NameError` for `params` is raised

#### Scenario: Standalone instantiation still works

- **WHEN** a bare class including `CamaleonCms::UploaderHelper` is instantiated
- **THEN** its uploader methods are callable without a controller

