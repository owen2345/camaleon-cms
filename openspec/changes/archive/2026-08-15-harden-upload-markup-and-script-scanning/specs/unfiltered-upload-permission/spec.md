## ADDED Requirements

### Requirement: The permission also authorizes executable script uploads

The system SHALL treat `media_unfiltered_upload` as the authority for uploading executable script
types (`js`, `mjs`, `cjs`, `wasm`, `swf`) in addition to its existing role of exempting an upload
from the content scan. A user without the permission SHALL be refused such an upload; a user holding
it SHALL be unaffected.

Reusing the existing permission rather than introducing a second one grants nothing new: a holder
already skips the content scan entirely and can therefore already store these files today. An
install that has granted the permission SHALL see no change in what its roles may upload.

The refusal for non-holders is an authorization outcome, not a scan verdict. Script content admits
no meaningful scan, so the check fails closed on the same terms as the scanning decision: an upload
with no current request user or no current site is refused, and an error while resolving the
permission is treated as not holding it.

#### Scenario: A role without the permission cannot upload script
- **WHEN** a user in a role that does not enable `media_unfiltered_upload` uploads a `.js` file
- **THEN** the upload is refused and no file is persisted

#### Scenario: A role with the permission is unaffected
- **WHEN** a user in a role whose `_manager_{site_id}` meta enables `media_unfiltered_upload` uploads a `.js` file
- **THEN** the upload is stored normally

#### Scenario: An administrator may upload script
- **WHEN** a user whose role is `admin` uploads a `.js` file
- **THEN** the upload is stored normally, through the administrator's `can :manage, :all` rule

#### Scenario: Upgrading does not widen what a role may upload
- **WHEN** an install whose stored role metas predate this permission is upgraded
- **THEN** roles other than `admin` are treated as not holding it and are refused script uploads

#### Scenario: A script upload with no request context is refused
- **WHEN** a `.js` upload is attempted while `CurrentRequest.user` or `CurrentRequest.site` is nil
- **THEN** the upload is treated as untrusted and refused
