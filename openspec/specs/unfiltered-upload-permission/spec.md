## Purpose

Define the role permission that decides whether an upload is scanned for malicious content. Uploaded files are served from the site's own origin and no server-enforced extension allowlist exists, so the content scan is the control that keeps an authenticated uploader from publishing active content there. Skipping it MUST be an authorization decision — never a property of where the source file happens to sit — and MUST be withheld from every default role but `admin`.

## Requirements

### Requirement: Unfiltered uploads are governed by a role permission

The system SHALL expose a `media_unfiltered_upload` permission in the manager section of the role editor, permitting users holding it to upload files without the content scan. It SHALL be presented as a dangerous permission, alongside the existing `post_content_unfiltered_html` and `contact_form_unfiltered_html` grants it parallels.

The permission is site-wide rather than per post type, because the media library is site-wide.

#### Scenario: The permission is offered in the role editor
- **WHEN** an administrator opens the role editor for an editable role
- **THEN** a `media_unfiltered_upload` checkbox is rendered among the manager permissions

#### Scenario: Granting the permission to a role authorizes its users
- **WHEN** a role's `_manager_{site_id}` meta records `media_unfiltered_upload` as enabled
- **THEN** `Ability#can?(:manage, :media_unfiltered_upload)` answers true for a user in that role

### Requirement: Only administrators hold the unfiltered-upload permission by default

The system SHALL NOT grant `media_unfiltered_upload` to any default role other than `admin`. Administrators satisfy it through `can :manage, :all`; the Editor, Contributor and Client roles are seeded with no manager permissions and therefore acquire it only if an operator grants it explicitly.

An existing install whose stored role metas predate this permission SHALL be treated as not granting it, so upgrading never widens what a role may upload.

#### Scenario: A freshly installed site withholds the permission from the editor role
- **WHEN** a site is installed and its default roles are seeded
- **THEN** the `editor` role's `_manager_{site_id}` meta does not enable `media_unfiltered_upload`

#### Scenario: A freshly installed site withholds the permission from the contributor role
- **WHEN** a site is installed and its default roles are seeded
- **THEN** the `contributor` role's `_manager_{site_id}` meta does not enable `media_unfiltered_upload`

#### Scenario: An administrator holds the permission
- **WHEN** a user whose role is `admin` is authorized for `media_unfiltered_upload`
- **THEN** the check answers true, through the administrator's `can :manage, :all` rule

### Requirement: The permission check fails closed without a request context

The system SHALL treat an upload as untrusted whenever the current request user or the current site is unavailable, so that background jobs, rake tasks, console sessions and any other caller outside a request are scanned rather than exempted. A failure while resolving the permission SHALL also be treated as untrusted.

#### Scenario: An upload with no request user is scanned
- **WHEN** upload content is checked while `CurrentRequest.user` is nil
- **THEN** the upload is treated as untrusted and the content scan runs

#### Scenario: An upload with no site context is scanned
- **WHEN** upload content is checked while `CurrentRequest.site` is nil
- **THEN** the upload is treated as untrusted and the content scan runs

#### Scenario: A malformed role meta does not abort the upload
- **WHEN** resolving the permission raises because the role meta is malformed
- **THEN** the upload is treated as untrusted rather than propagating the error

