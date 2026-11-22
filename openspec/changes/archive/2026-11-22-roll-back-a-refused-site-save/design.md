# Design

## Context

See `proposal.md`, "Why". The archived change `2026-11-22-roll-back-a-refused-draft-save` kept the
old rule for each admin save except the post save and the draft save. By that rule, a refused save
keeps what it stored before the custom-field values. This change replaces that rule for the site
settings save, because only that save stores a value that the redirect of the refusal depends on.

## Goals / Non-Goals

**Goals:**

- A refused site settings save keeps the slug of the site.
- The redirect of the refusal leads to the form of the site, with the message.
- The answer to an XHR without the `cama_ajax_request` param does not change.
- After a rollback, `PluginRoutes.get_sites` holds each site as stored, unless code in that
  transaction reloaded the routes or asked for a reload, as a post type does.

**Non-Goals:**

- The other admin saves that store their record before the custom-field values, such as the
  category save. They keep the old rule.
- A site that got a new slug from an earlier refused save (D4).
- The moment at which a post type asks for the reload of the routes (D5).

## Decisions

**D1. The site settings save writes in one transaction.**
`SettingsController#save_site_with_fields` opens `ActiveRecord::Base.transaction`, updates the site
and then writes the options, the metas and the custom-field values. A refusal raises through the
transaction, which rolls back. The `rescue_from` of `AdminController` then answers as before.

- *Alternative: run the shared permit before the update.* Rejected: only the refusal of the permit
  comes before the first write then. A refused custom-field value and a refused options or metas
  container come from the writers, after the update.
- *Alternative: redirect a refusal to the new host.* Rejected: the session cookie belongs to the old
  host, so the new host shows no flash, and it can ask for a sign-in. The site also keeps half of
  a refused save.

**D2. A refused save rolls back each part, not only the slug.** A transaction that holds only the
slug needs a second save of the site. A refused post save and a refused draft save store nothing,
and the site settings save now agrees with them.

**D3. The validation failure of the site keeps its answer.** The method raises
`ActiveRecord::Rollback` when the update returns false, and the action renders the form again.

**D4. A slug from an earlier refused save stays.** No record says that a slug came from a refused
save. An administrator who wants the old slug back stores it in the settings form on the new host.

**D5. A site asks for the reload of the routes after the commit.** `Site` called
`PluginRoutes.request_reload` in `after_save` for a new slug, and in `after_destroy`. Both run in
the transaction. The reload fills the list of `PluginRoutes.get_sites` with the data of the
transaction, and a rollback does not clear that list.

Now `Site` asks for the reload in `after_commit`. A create and a delete always ask for it, as
before.

An update asks for the reload when the list of `PluginRoutes.get_sites` does not hold the stored
slug of the site. The callback reads the stored slug from the database, and it keeps no record on
the instance. Two facts of Rails make such a record wrong:

- `saved_change_to_attribute?(:slug)` is false in `after_commit` when a second save of the instance
  follows the save of the new slug.
- For each row of a transaction, Rails runs the commit callbacks of one instance. The site settings
  save stores the new slug through one instance, and the custom-field values then save the site
  through another instance. The first instance gets no commit callback.

A list that is not loaded holds no old slug: the next read loads the stored sites. So the callback
reads `PluginRoutes.loaded_sites` first, which loads nothing. When the list is not loaded, the
callback asks for no reload and reads no slug.

A save or a delete outside a transaction commits at once, so its reload comes right after it, as
before. The draws of a site create and of a site delete keep their number. Each commit of a site
update costs one query for the stored slug while the list is loaded.

A post type keeps its reload in the transaction. A new post type, or a new slug of a post type,
adds a route. `PluginRoutes.request_reload` draws such a route at once, so that a hook or a
callback later in the same transaction finds the route helper.

- *Alternative: a record on the instance that `after_save` sets and `after_commit` reads.*
  Rejected: the spec of the site settings save failed with it, for the second fact above.
- *Alternative: a reload in `after_rollback`.* Not chosen: it draws the routes one more time for
  each rollback, and the reload in the transaction still reads data that is not stored.
- *Alternative: a method of `PluginRoutes` that clears only the list of sites.* Not chosen: it adds
  a public method for a rare case.
- *Alternative: a reload only in `SettingsController`.* Not chosen: other code that rolls back a
  new slug leaves the same list.

## Risks / Trade-offs

- In a transaction that changes the slug of a site, or destroys a site, `PluginRoutes.get_sites`
  holds the stored sites until the commit. Before, code in that transaction read the change at once.
  Camaleon has no such code, and no surveyed plugin or theme has it. The upgrade guide names
  `PluginRoutes.reload` for that case.
- An error of the reload now comes after the commit, so it does not roll the change back.
- A post type that is created in the same transaction still reloads the routes in the transaction.
  That reload reads a new slug of the site before the commit. After a rollback of such a
  transaction, the list holds that slug until the next reload. A site create creates the post
  types of the site, so after a rollback of a site create the list holds that site.
- A refused save no longer stores the new name, description, options and metas. The administrator
  sends the form again after the correction of the refused part.
