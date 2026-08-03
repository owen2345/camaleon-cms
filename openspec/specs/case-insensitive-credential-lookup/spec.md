## Purpose

Define how user-typed usernames and email addresses are resolved against their stored, downcased forms. Every lookup that resolves such input must compare case-insensitively regardless of the database collation, so mixed-case input still finds the stored user.

## Requirements

### Requirement: Username and email lookups are case-insensitive

Usernames and emails are stored downcased, so every lookup that resolves user-typed input SHALL
compare case-insensitively via the custom class finders `find_by_username` / `find_by_email`
(which lower-case both sides in SQL), regardless of the database collation. This covers the login
action, the password-reset email lookup, `SessionHelper#login_user_with_password`, and
`SiteDecorator#the_user(username)`.

#### Scenario: Mixed-case username signs in

- **WHEN** a user whose stored username is `admin` submits the login form with username `Admin`
  and their correct password
- **THEN** authentication succeeds and the user reaches the dashboard

#### Scenario: Mixed-case address receives the password-reset email

- **WHEN** a user whose stored email is `admin@local.com` submits `Admin@Local.com` on the
  forgot-password form
- **THEN** the reset email is sent and the success message is shown

#### Scenario: Theme API resolves a mixed-case username

- **WHEN** a theme calls `site.the_user('ADMIN')` for a user stored as `admin`
- **THEN** the decorated user is returned instead of `nil`
