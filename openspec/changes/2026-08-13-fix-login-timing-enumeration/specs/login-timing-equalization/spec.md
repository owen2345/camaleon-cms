## Purpose

Ensure the admin login does not reveal whether a username exists through response timing. Verifying a
password only when the account exists lets an attacker distinguish a valid username (slow bcrypt path)
from an unknown one (fast no-op), enumerating accounts.

## ADDED Requirements

### Requirement: Login equalizes password-verification timing for unknown usernames

The admin login SHALL perform a bcrypt password comparison on every attempt, including when the
submitted username does not exist, so that an unknown username is not distinguishable from a wrong
password by response time. The comparison for a missing username SHALL NOT authenticate any account.

#### Scenario: A missing username still performs a hash comparison

- **WHEN** a login is attempted with a username that does not exist
- **THEN** a bcrypt hash comparison is performed and the attempt is rejected

#### Scenario: A valid credential still authenticates

- **WHEN** a login is attempted with an existing username and its correct password
- **THEN** the user is authenticated
