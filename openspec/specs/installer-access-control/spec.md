## Purpose

Controls who may run the first-run site installer and who may view the credentials it produces, so
that provisioning a Camaleon install cannot be performed, or observed, by an unauthenticated party
who merely reaches the application over the web.

## Requirements

### Requirement: Installer requires a setup token for remote requests on a fresh deploy

While no site exists (a fresh deploy), the installer SHALL refuse a remote request to provision a
site without a valid setup token. A request originating from the local host (loopback) SHALL be
exempt, because local access already demonstrates operator-level access to the host.

#### Scenario: A remote request without a valid token is refused
- **WHEN** a remote request submits the installer's create action on a fresh deploy with no setup token, or an incorrect one
- **THEN** no site is created
- **AND** the response does not provision an administrator or disclose any credentials

#### Scenario: A remote request with the valid token succeeds
- **WHEN** a remote request submits the installer's create action on a fresh deploy with the correct setup token
- **THEN** the site is provisioned

#### Scenario: A local request may provision without a token
- **WHEN** a request from the local host submits the installer's create action on a fresh deploy without a setup token
- **THEN** the site is provisioned

### Requirement: The setup token comes only from the server

The setup token SHALL be obtainable only from the server's environment or filesystem, never from the
web surface. So possession of it demonstrates operator-level access to the host.

#### Scenario: The web surface does not disclose the setup token

- **WHEN** any party reads a page or a response of the web surface of the installer
- **THEN** the setup token is not in it

### Requirement: The setup token is single-use for provisioning

The setup token SHALL be single-use for provisioning. Once a site is successfully created, the token
SHALL no longer be accepted.

#### Scenario: The token cannot be replayed after setup completes
- **WHEN** a site already exists and a request submits the installer's create action with the previously valid setup token
- **THEN** the request is refused and no second provisioning occurs

### Requirement: The installer is closed once a site exists

Once at least one site exists, the installer's provisioning actions SHALL NOT be reachable, and SHALL
redirect away rather than render.

#### Scenario: Installer entry is closed after installation
- **WHEN** any party requests the installer index or create action and at least one site already exists
- **THEN** the request is redirected away without provisioning

### Requirement: The welcome page is restricted to the operator who just completed setup

The post-install welcome page — which discloses the newly provisioned administrator's credentials —
SHALL be viewable only via a one-time indication established when that same session completed setup.
It SHALL NOT be reachable by an anonymous visitor, and SHALL NOT remain reachable after a site
exists. The one-time indication SHALL be cleared when the welcome page is shown, so the credentials
are disclosed at most once.

#### Scenario: Anonymous visitor cannot read the welcome page
- **WHEN** a visitor requests the welcome page without having completed setup in the current session
- **THEN** the page is not served and no credentials are disclosed

#### Scenario: The operator sees the welcome page once
- **WHEN** the operator who just completed setup is redirected to the welcome page
- **THEN** the page is served and the generated credentials are shown
- **AND** a subsequent request for the welcome page no longer discloses the credentials
