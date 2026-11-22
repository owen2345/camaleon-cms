## ADDED Requirements

### Requirement: A site asks for the reload of the routes after the commit of its transaction

A site SHALL ask for the reload of the routes when it is created, when it gets a new slug and when
it is deleted. It SHALL ask with `PluginRoutes.request_reload`, after the commit of the transaction
that holds the change, and one time for that transaction. A transaction that rolls back
SHALL ask for no reload.

After a rollback, the list of `PluginRoutes.get_sites` MUST hold each site as stored, unless code in
that transaction loaded the list. A reload of the routes, a reload request and a read of the list
while it is not loaded each load the list. A site create creates its post types, which ask for a
reload, so the list can hold a site whose create rolled back.

A commit of a site update SHALL ask for no reload when the list of `PluginRoutes.get_sites` holds
the stored slug of that site. When the list is not loaded, the commit SHALL ask for no reload, and
it SHALL NOT load the list.

#### Scenario: A new slug outside a transaction

- **WHEN** code saves a site with a new slug, outside a transaction, while the list of
  `PluginRoutes.get_sites` is loaded
- **THEN** the routes are drawn one time, and the list of `PluginRoutes.get_sites` holds the new slug

#### Scenario: A new slug that a transaction rolls back

- **WHEN** a transaction saves a site with a new slug, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the stored slug

#### Scenario: A second save after the new slug

- **WHEN** a transaction saves a site with a new slug, and then saves that site again, while the
  list of `PluginRoutes.get_sites` is loaded
- **THEN** the routes are not drawn in the transaction
- **AND** they are drawn one time after the commit

#### Scenario: A new slug and a save through another instance

- **WHEN** the site settings save stores a new slug, and its custom-field values then save the site
  through another instance, in one transaction
- **THEN** the list of `PluginRoutes.get_sites` holds the new slug after the commit

#### Scenario: A save with no new slug

- **WHEN** code saves a new name of a site, and the list holds the stored slug of that site
- **THEN** the routes are not drawn

#### Scenario: A new slug while the list is not loaded

- **WHEN** code gives a site a new slug while the list of `PluginRoutes.get_sites` is not loaded
- **THEN** the routes are not drawn, and the commit does not load the list
- **AND** the next read of the list holds the new slug

#### Scenario: A delete that a transaction rolls back

- **WHEN** a transaction destroys a site, and then rolls back
- **THEN** the routes are not drawn, and the list of `PluginRoutes.get_sites` holds the site
