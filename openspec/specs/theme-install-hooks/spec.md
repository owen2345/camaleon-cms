# theme-install-hooks Specification

## Purpose

A theme has an `on_active` hook and an `on_inactive` hook. This capability says which of them a
theme install and a site create run. It also says which theme is the current theme of the request
while they run.

## Requirements

### Requirement: A theme is the current theme while its install and uninstall hooks run

The install of a theme runs the `on_active` hook of that theme. While that hook runs, the current
theme of the request SHALL be the theme that is installed. The `on_active` handler SHALL get the
record of the theme that is installed as its argument.

#### Scenario: The on_active handler reads the current theme

- **WHEN** an administrator installs a theme in the admin panel, and the `on_active` handler of that
  theme reads the current theme
- **THEN** the current theme is the theme that is installed, and it is the record that the handler
  got as its argument

### Requirement: A hook that the on_active handler fires goes to the installed theme

A hook that a handler of `on_active` fires SHALL go to the theme that is installed. That hook MUST
NOT go to the theme before the install.

#### Scenario: The on_active handler fires a hook that the installed theme handles

- **WHEN** the `on_active` handler of the theme that is installed installs a plugin
- **AND** both themes register a handler for the after-install hook of that plugin
- **THEN** the handler of the theme that is installed runs one time, and the handler of the theme
  before the install does not run

### Requirement: The on_inactive hook runs with the old theme as the current theme

The install over another theme first runs the `on_inactive` hook of the theme before the install.
While that hook runs, the current theme of the request SHALL be the theme before the install.

#### Scenario: The on_inactive handler reads the current theme

- **WHEN** an administrator installs a theme in the admin panel, and the `on_inactive` handler of the
  theme before the install reads the current theme
- **THEN** the current theme is the theme before the install

### Requirement: A theme preview is the current theme again after each install hook

A user who can manage themes can preview a theme: the request then shows the site with that theme as
its current theme. The rules of the three requirements above, on the `on_active` and `on_inactive`
hooks, SHALL also hold in such a request. After each hook, the
current theme of that request SHALL be the preview theme again, also when a handler raises.

#### Scenario: A request with a theme preview installs a theme

- **WHEN** a request previews a theme, and code of that request installs another theme
- **THEN** the `on_inactive` handler reads the theme before the install as the current theme
- **AND** the `on_active` handler reads the theme that is installed as the current theme
- **AND** after the install, the current theme is the preview theme, and the page shows that theme

#### Scenario: A handler raises in a request with a theme preview

- **WHEN** a request previews a theme, code of that request installs another theme, and the
  `on_active` handler raises
- **THEN** the caller gets that error, and the current theme of the request is the preview theme

### Requirement: A handler runs one time for each dispatch of its hook

A handler SHALL run one time for each dispatch of its hook. A direct call of the handler from theme
code is no dispatch, so Camaleon SHALL NOT prevent a second run by such a call.

#### Scenario: The on_active handler also calls its handler directly

- **WHEN** the `on_active` handler installs a plugin, and it also calls its own handler of the
  after-install hook of that plugin directly
- **THEN** that handler runs two times: one time for the hook and one time for the direct call

### Requirement: The theme of a new site gets the hooks of the site create

The create of a site installs the default plugins and then the theme of the site. The theme of the
new site SHALL be the theme that the create names, before the first default plugin is installed. A
hook that the install of a default plugin fires SHALL go to that theme, and it MUST NOT go to
another theme.

#### Scenario: The installer creates a site with a theme that is not the default theme

- **WHEN** the installer creates the first site with a theme that is not the default theme
- **AND** that theme and the default theme register a handler for the `plugin_after_install` hook
- **THEN** the handler of the theme of the site runs one time for each default plugin
- **AND** the handler of the default theme does not run

### Requirement: A site create makes one theme record

The create SHALL make one theme record for the site, for the theme that the create names. That
record SHALL have the name that the config of the theme gives.

#### Scenario: The new site has one theme record

- **WHEN** the installer creates the first site with a theme that is not the default theme
- **THEN** the site has one theme record, for the theme of the site
- **AND** that record has the name that the config of the theme gives

#### Scenario: The admin panel creates a site with the default theme

- **WHEN** an administrator creates a site in the admin panel
- **THEN** the theme record of the site has the name that the config of the default theme gives

### Requirement: A site create in a request with a theme preview keeps the preview theme

A theme preview is a theme of the site of the request. The rules above SHALL also hold in a request
with a theme preview. No hook of the create SHALL go to the preview theme. After the create, the
current theme of that request SHALL be the preview theme again, also when a handler raises.

#### Scenario: A request with a theme preview creates a site

- **WHEN** a request previews a theme, and code of that request creates a site
- **THEN** the hooks of the default plugin installs go to the theme of the new site, and not to the
  preview theme
- **AND** after the create, the current theme is the preview theme, and the page shows that theme

#### Scenario: A handler raises during a site create in a request with a theme preview, for the current theme

- **WHEN** a request previews a theme, code of that request creates a site, and a handler of a
  default plugin hook raises
- **THEN** the caller gets that error, and the current theme is the preview theme

### Requirement: A site create restores the current site

After the create, the current site of the request SHALL be the site that it had before the create,
also when a handler raises.

#### Scenario: A handler raises during a site create, for the current site

- **WHEN** a request previews a theme, code of that request creates a site, and a handler of a
  default plugin hook raises
- **THEN** the caller gets that error, and the current site is the site of the request

### Requirement: The create of a site runs no on_inactive hook

A new site has no theme to uninstall. The create of a site SHALL run the `on_active` hook of the
theme of the site one time. It SHALL NOT run an `on_inactive` hook of any theme. A value that a
handler stores on the theme record during the create SHALL be on that record when `on_active` runs.

The install of a theme on a site that already has a theme SHALL still run the `on_inactive` hook of
the theme before the install. This includes the install of the theme that the site already has.

#### Scenario: A site create runs on_active only

- **WHEN** an administrator creates a site in the admin panel, and the theme of the site registers an
  `on_inactive` handler and an `on_active` handler
- **THEN** the `on_active` handler runs one time, and the `on_inactive` handler does not run

#### Scenario: A value that a plugin hook stored is there in on_active

- **WHEN** the installer creates a site, and a `plugin_after_install` handler of the theme of the
  site stores an option on the theme record
- **AND** the `on_inactive` handler of that theme destroys the theme record
- **THEN** the `on_active` handler reads that option from its argument

#### Scenario: An administrator installs the theme that the site already has

- **WHEN** an administrator installs the current theme of the site again in the admin panel
- **THEN** the `on_inactive` handler of that theme runs, and then its `on_active` handler runs

### Requirement: An install refuses a theme that is not installed

An install of a theme and a site create SHALL refuse a theme key that no installed theme has. The
refusal SHALL come before the first write, so the site keeps its theme and its theme records.

#### Scenario: An administrator installs a theme that is not installed

- **WHEN** an administrator opens the theme page with a theme key that no installed theme has
- **THEN** the page shows an error, and the site keeps its theme and its theme records

### Requirement: A refused theme install reports the error at each entry point

The install helpers SHALL raise `ArgumentError`. The theme page of the admin panel SHALL show an
error. The installer and the site create of the admin panel SHALL show their form again with an
error, and they SHALL create no site.

#### Scenario: The installer gets a theme that is not installed

- **WHEN** the installer gets a theme key that no installed theme has
- **THEN** it shows its form again with an error, and it creates no site

#### Scenario: Code installs a theme that is not installed

- **WHEN** code calls `site_install_theme` or `site_after_install` with such a key
- **THEN** the helper raises `ArgumentError` before its first write

### Requirement: The default theme of the system config can be a theme that is not installed

A site create with no theme of its own installs the default theme of the system config
(`default_template`). A host can name a theme there that is not installed, and the rules above SHALL
also hold for that theme.

#### Scenario: The default theme of the system config is not installed

- **WHEN** the system config names a default theme that is not installed
- **AND** an administrator creates a site in the admin panel, or the installer gets a request with
  no theme
- **THEN** the form shows again with an error, and the create makes no site

### Requirement: A theme switch is all or nothing

`site_install_theme` SHALL run the uninstall of the old theme and the install of the new theme in
one transaction. In a transaction of the caller, that transaction SHALL be a savepoint. When a step
raises, for example the `on_active` handler of the new theme, the helper SHALL give the error to the
caller.

#### Scenario: A role without the select_eval permission switches to a theme that adds a select_eval field

- **WHEN** a role with the `themes` permission and no `select_eval` permission switches the theme
  in the admin panel
- **AND** the `on_active` handler of the new theme installs a plugin, adds a field group with a
  field, and then adds a `select_eval` field
- **THEN** the response redirects to the dashboard with the error of the refusal
- **AND** the site keeps its theme key, its theme records and its plugins
- **AND** no field group of the handler is stored, and `PluginRoutes` gives no enabled plugin of the
  handler
- **AND** the front page answers with a 200 and shows the old theme

#### Scenario: A failed switch that is the first statement of a transaction of the caller

- **WHEN** a transaction of the caller ran no statement, code in it calls `site_install_theme`, and
  a hook of the switch raises
- **THEN** the switch rolls back to its own savepoint, and Rails does not restart the transaction of
  the caller

### Requirement: A failed theme switch restores the site and the request

After a step raises, the site SHALL keep the theme key that it had before the switch. Its theme
records SHALL stay as they were, and no row that a hook of the switch wrote SHALL stay. The cached
data of `PluginRoutes` MUST hold no data of the switch. The current theme of the request SHALL be
the theme that it had before the switch, also after an exception that is no `StandardError`.

#### Scenario: Code rescues the error of a switch

- **WHEN** code in a request calls `site_install_theme`, the `on_active` handler of the new theme
  raises, and the code rescues the error
- **THEN** `current_theme` is the old theme, and the theme key of `current_site` is the old key
- **AND** the page of the request shows the old theme

#### Scenario: A hook raises an exception that is no StandardError

- **WHEN** code calls `site_install_theme`, the `on_active` handler of the new theme raises
  `SystemStackError`, and the code rescues that error
- **THEN** the site keeps its old theme, and the current theme of the request is the old theme

### Requirement: A failed theme switch draws the routes again

A hook can draw the routes of the app from the rows of the switch. The helper then SHALL draw them
again before it gives the error, for an exception of any class.

#### Scenario: A hook draws the routes and then raises

- **WHEN** code calls `site_install_theme`, and the `on_active` handler of the new theme installs a
  plugin and then raises `SystemStackError`
- **THEN** the helper draws the routes of the app again before it gives the error

### Requirement: A failed theme switch resets the associations of the current site

The helper SHALL reset the `themes` and the `plugins` associations of the current site. A later save
of that site MUST NOT store a theme or a plugin of the switch. A switch that fails before its
transaction begins SHALL leave the two associations as they were.

#### Scenario: The request saves its site after the error of a switch

- **WHEN** code calls `site_install_theme` with no transaction of its own, and a hook of the switch
  installs a plugin and then raises
- **AND** the code rescues the error and saves the current site
- **THEN** the site has the theme records and the plugin records that it had before the switch
- **AND** the rollback left the records of the switch in the associations in memory
- **AND** the reset keeps a save of the site from storing them again

#### Scenario: A record that a hook created through another association stays in memory

- **WHEN** a hook of a failed switch creates a record through another association of a record in
  memory, such as `current_site.post_types`
- **THEN** that record stays in that association

### Requirement: A commit callback that raises after the commit keeps the switch

A commit callback can raise after the commit of the switch, and the helper SHALL give that error to
the caller. The switch then SHALL stay, and the current theme of the request SHALL be the new theme.
The helper SHALL draw the routes of the app before it gives the error, and it SHALL log an error of
that draw.

#### Scenario: A commit callback raises after the commit of the switch

- **WHEN** code calls `site_install_theme` outside a transaction that others can join
- **AND** a commit callback of a row that a hook of the switch wrote raises after the commit
- **THEN** the helper gives the error to the caller
- **AND** the site has the new theme, and the current theme of the request is the new theme
- **AND** the helper draws the routes of the app, and `PluginRoutes` gives the new theme as the
  enabled theme

### Requirement: A commit callback in a transaction of the caller runs at its commit

In a transaction of the caller that others can join, the switch has no commit of its own. Rails then
runs the commit callbacks at the commit of the caller, after the helper returned. The error of a
callback then SHALL come from that commit.

#### Scenario: A commit callback raises in a transaction of the caller that others can join

- **WHEN** code calls `site_install_theme` in a transaction of the caller that others can join
- **AND** a commit callback of a row that the switch wrote raises
- **THEN** the helper returns with no error
- **AND** the error comes from the commit of the caller

### Requirement: The trial draw of the routes runs in the transaction of the switch

The trial draw of the routes SHALL run in the transaction of the switch. The draw of the app routes
that the switch asks for SHALL run after that transaction. After the commit of the switch, that draw
SHALL run a trial again, and read the rows that other connections stored meanwhile.

#### Scenario: Another connection stores a row during the switch

- **WHEN** another connection commits a new name of a site after the trial of a switch, and the
  switch then commits
- **THEN** the draw of the switch runs a trial again, and `PluginRoutes.get_sites` gives the new name

### Requirement: A draw at once in an open transaction of the caller uses the trial data

In a transaction of the caller that is still open, a draw at once SHALL use the data of the trial.
When another reload drew the routes after the trial, a draw at once SHALL run a trial again.

#### Scenario: A draw at once in a transaction of the caller

- **WHEN** a hook asks for a draw of the routes at once in a transaction of the caller that is still
  open
- **THEN** the draw uses the data of the trial
- **AND** when another reload drew the routes after the trial, the draw runs a trial again

### Requirement: A draw in a reload_once block or by a hook

In a `PluginRoutes.reload_once` block, the draw can wait for the end of the block instead, and that
draw SHALL run a trial of its own. A draw that a hook starts, for example through `plugin_install`,
SHALL run in the transaction.

#### Scenario: A draw waits for the end of a reload_once block

- **WHEN** a hook of the switch asks for a draw in a `PluginRoutes.reload_once` block
- **THEN** the draw can wait for the end of the block, and it runs a trial of its own

#### Scenario: A hook starts a draw through plugin_install

- **WHEN** a hook of the switch installs a plugin through `plugin_install`
- **THEN** the draw that the install starts runs in the transaction

### Requirement: A reload by a commit callback of the switch needs no second trial

A commit callback of the switch can reload the routes after the commit, for example for a new slug
of a post type. That reload is another reload after the trial, but it reads the rows of the switch.
So the draw of the switch SHALL NOT run a trial again, and it SHALL NOT draw the routes again. This
holds while no other thread drew the routes after that reload. It is an exception to "The trial draw
of the routes runs in the transaction of the switch".

#### Scenario: A hook gives a post type a new slug

- **WHEN** the `on_active` hook of the new theme gives a post type a new slug, with no transaction
  of the caller
- **THEN** Camaleon draws the routes of the app one time after the commit, with the new slug and the
  new theme

### Requirement: A request that starts during a switch waits for it

`site_install_theme` SHALL take `CamaleonCms::RouteReloadLock` exclusively before it opens its
transaction, and hold it until the helper returns or raises. A request that starts during the switch
SHALL wait until the switch is done.

#### Scenario: A request starts during a switch

- **WHEN** a request starts while `site_install_theme` runs
- **THEN** the request waits until the switch is done

### Requirement: A draw during a switch does not wait for a request that waits for the lock

A draw that a hook starts in the transaction SHALL NOT wait for a request that waits for a lock of
that transaction. A reload of another thread SHALL NOT wait for the switch longer than the wait time
of the lock.

#### Scenario: A request starts during a switch whose hook draws the routes

- **WHEN** a request starts while `site_install_theme` runs, and a hook of the switch installs a
  plugin
- **THEN** the request waits until the switch is done
- **AND** the draw of the routes that the plugin install starts does not wait for that request

### Requirement: A switch waits for another thread that holds the lock

Another thread can hold the lock, for example a second theme switch. The helper MUST NOT run the
switch with no lock. It SHALL wait for that thread, for
`CamaleonCms::RouteReloadLock::HOLDER_WAIT_TIMEOUT` seconds at most.

#### Scenario: A second switch waits for the switch that holds the lock

- **WHEN** a theme switch holds the lock longer than the wait time of the lock, and code calls
  `site_install_theme` in another thread
- **THEN** the second switch runs no hook before the first switch is done
- **AND** it then switches the theme with the lock

### Requirement: A switch that waits too long raises WaitTimeout

After `HOLDER_WAIT_TIMEOUT` seconds, the helper SHALL raise
`CamaleonCms::RouteReloadLock::WaitTimeout` before its first write, and the site SHALL keep its
theme. The theme switch of the admin SHALL answer that error with a redirect to the list of the
themes and a flash error.

#### Scenario: A second switch that waits too long

- **WHEN** another thread still holds the lock after `HOLDER_WAIT_TIMEOUT` seconds of a call of
  `site_install_theme`
- **THEN** the helper raises `CamaleonCms::RouteReloadLock::WaitTimeout`, and the site keeps its theme
- **AND** the admin panel redirects to the list of the themes with a flash error

### Requirement: A switch reads the theme of the site again after it takes the lock

Another theme switch can end before the helper takes the lock, also after the caller read the site.
The switch SHALL read the theme of the site again after it takes the lock. It SHALL run the
`on_inactive` hook of the theme that the other switch stored, and it SHALL keep the options that the
other switch stored.

#### Scenario: A switch after a switch of another request

- **WHEN** a request read its site, another request then switches the theme, and the first request
  calls `site_install_theme`
- **THEN** the switch runs the `on_inactive` hook of the theme that the other request stored
- **AND** the site keeps an option that a hook of the other switch stored

### Requirement: A switch in a transaction of the caller with a snapshot reads the snapshot rows

A transaction of the caller can hold a snapshot of the database from before the other switch. MySQL
gives such a snapshot with its default isolation level. The switch then SHALL read the rows of that
snapshot.

#### Scenario: A transaction of the caller on MySQL holds a snapshot

- **WHEN** a transaction of the caller on MySQL holds a snapshot from before another switch, and
  code calls `site_install_theme` in it
- **THEN** the switch reads the rows of that snapshot

### Requirement: A switch in a REPEATABLE READ transaction on PostgreSQL can raise SerializationFailure

A transaction of the caller on PostgreSQL under REPEATABLE READ holds such a snapshot too. The first
write of the switch to a row that the other switch changed SHALL raise
`ActiveRecord::SerializationFailure`. The switch SHALL roll back to its savepoint, and the caller
MUST run its transaction again.

#### Scenario: A write of the switch conflicts with another switch under REPEATABLE READ

- **WHEN** a transaction of the caller on PostgreSQL under REPEATABLE READ holds a snapshot from
  before another switch, and code calls `site_install_theme` in it
- **AND** the first write of the switch is to a row that the other switch changed
- **THEN** that write raises `ActiveRecord::SerializationFailure`
- **AND** the switch rolls back to its savepoint, and the caller must run its transaction again

### Requirement: A switch loads the metas of the site in memory again

A site object can hold its metas in memory, for example a site of `PluginRoutes.get_sites`. The
switch SHALL load those metas again after it takes the lock. Metas that hold a meta or a change that
is not saved SHALL stay as they are, and the switch then reads the old rows.

#### Scenario: A switch after a switch of another request, with the metas of the site in memory

- **WHEN** a request read its site with its metas, another request then switches the theme, and the
  first request calls `site_install_theme`
- **THEN** the switch runs the `on_inactive` hook of the theme that the other request stored
- **AND** the site keeps an option that a hook of the other switch stored

#### Scenario: Metas with a change that is not saved stay as they are

- **WHEN** the metas of a site in memory hold a meta or a change that is not saved, and code calls
  `site_install_theme`
- **THEN** the metas stay as they are, and the switch reads the old rows

### Requirement: A hook that raises ActiveRecord::Rollback rolls back the switch

A hook can raise `ActiveRecord::Rollback` outside a `transaction` block of its own. A
`before_commit` callback can raise it at the commit of the switch. The switch then SHALL roll back
as for any other error, and the helper SHALL raise `ActiveRecord::ActiveRecordError`.

#### Scenario: A hook raises ActiveRecord::Rollback

- **WHEN** code calls `site_install_theme`, and the `on_active` handler of the new theme writes a row
  and then raises `ActiveRecord::Rollback`
- **THEN** the helper raises `ActiveRecord::ActiveRecordError`
- **AND** the site keeps its old theme, and the row of the handler is not stored
- **AND** the current theme of the request is the old theme

#### Scenario: A before_commit callback raises ActiveRecord::Rollback

- **WHEN** code calls `site_install_theme` outside a transaction that others can join
- **AND** a `before_commit` callback of a row that the switch wrote raises `ActiveRecord::Rollback`
- **THEN** the helper raises `ActiveRecord::ActiveRecordError`
- **AND** the site keeps its old theme, and the current theme of the request is the old theme

### Requirement: A failed statement on PostgreSQL rolls back the switch

On PostgreSQL, a statement that fails stops the transaction of the switch, also when a hook or a
read of the trial rescues its error. When no step raises another error, the switch then SHALL roll
back, and the helper SHALL raise `ActiveRecord::StatementInvalid`.

#### Scenario: A hook rescues a failed statement on PostgreSQL

- **WHEN** a hook of the switch runs a statement that fails on PostgreSQL, and the hook rescues the
  error
- **AND** no step raises another error
- **THEN** the switch rolls back, and the helper raises `ActiveRecord::StatementInvalid`

### Requirement: The rollback of a switch does not undo a change outside the database

The rollback of a switch SHALL NOT undo a change outside the database. Such a change is a file that
a hook writes or a mail that it sends.

#### Scenario: A hook writes a file and the switch rolls back

- **WHEN** a hook of the switch writes a file or sends a mail, and the switch rolls back
- **THEN** the file stays and the mail is sent

### Requirement: A DDL statement in a hook on MySQL commits the transaction at once

On MySQL, a DDL statement in a hook, such as `create_table`, commits the transaction at once. A
switch that fails after that statement SHALL keep every row that it wrote, also the rows after the
statement.

#### Scenario: A hook runs a DDL statement and then raises on MySQL

- **WHEN** a hook of the switch runs `create_table` on MySQL, writes a row, and then raises
- **THEN** the switch keeps every row that it wrote, also the row after the statement

### Requirement: The end of a switch with a DDL statement in a transaction of the caller raises a database error

In a transaction of the caller on MySQL, the savepoint of the switch is gone after a DDL statement
in a hook. So the end of the switch SHALL raise an error of the database, also when no hook raises.
A switch whose hook raises SHALL then give that error, not the error of the hook.

#### Scenario: A DDL statement in a hook in a transaction of the caller on MySQL

- **WHEN** a hook of the switch runs `create_table` on MySQL in a transaction of the caller
- **THEN** the end of the switch raises an error of the database, also when no hook raises
- **AND** when a hook raises, the helper gives that error of the database and not the error of the
  hook

### Requirement: A switch in a transaction of the caller that has a pool isolation level raises TransactionIsolationError

Rails 8.1 permits no savepoint while the connection pool has a transaction isolation level. In a
transaction of the caller, the helper then SHALL raise `ActiveRecord::TransactionIsolationError`
before its first write. The caller SHALL keep its connection and its transaction.

#### Scenario: The caller sets an isolation level in its open transaction

- **WHEN** code on Rails 8.1 opens a transaction, and then calls `site_install_theme` in an
  `ActiveRecord.with_transaction_isolation_level` block
- **THEN** Rails refuses the transaction of the switch with
  `ActiveRecord::TransactionIsolationError`, because the pool has no such level
- **AND** the site keeps its theme

#### Scenario: A transaction of the caller that got the pool isolation level

- **WHEN** code on Rails 8.1 opens a transaction in an
  `ActiveRecord.with_transaction_isolation_level` block, and calls `site_install_theme` in that
  transaction
- **THEN** the helper raises `ActiveRecord::TransactionIsolationError` before Rails raises it for a
  savepoint
- **AND** Rails drops the connection and the transaction when it raises that error for a savepoint
- **AND** the caller keeps its connection and its open transaction

### Requirement: The transaction of a switch is on the connection pool of ActiveRecord::Base

The transaction of the switch SHALL be on the connection pool of `ActiveRecord::Base`. It SHALL NOT
cover a host that puts the Camaleon models on another pool.

#### Scenario: A host puts the Camaleon models on another pool

- **WHEN** a host puts the Camaleon models on another connection pool, and code calls
  `site_install_theme`
- **THEN** the transaction of the switch is on the pool of `ActiveRecord::Base`, and it does not
  cover the models on the other pool

### Requirement: The switch leases no database connection for good

`site_install_theme` SHALL NOT lease a database connection to the thread for good, as
`ActiveRecord::Base.connection` does. So the switch works where a host refuses such a lease (Rails
7.2 and later, `permanent_connection_checkout`).

#### Scenario: A host refuses a permanent connection lease

- **WHEN** a host refuses a permanent lease of a database connection, and code calls
  `site_install_theme`
- **THEN** the helper raises no error, and the site has the new theme
