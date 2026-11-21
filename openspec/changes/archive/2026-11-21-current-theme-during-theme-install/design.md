# Design

## Context

See `proposal.md`, "Why". Four facts of the code shape the fix:

- `current_theme` (`CamaleonCms::SiteHelper`) reads `CurrentRequest.frontend_current_theme` and
  fills it from `current_site.get_theme` on the first read. `current_site(site)` clears it.
- Each admin request runs the `admin_before_load` hook before its action. `hooks_run` reads
  `current_theme` there, so the request holds the theme before the install when the action starts.
- `site_install_theme` stores the new theme slug and activates the theme record. It then runs
  `on_active` with that record, and it does not change `CurrentRequest.frontend_current_theme`.
- A frontend request can preview a theme: a user who can manage themes adds `ccc_theme_preview` to
  the URL. `FrontendController` then stores the preview theme in `@_current_theme`. `current_theme`
  reads that variable first, and it writes the preview theme to `CurrentRequest` on each read.

`site_after_install` calls `current_site(site)` before the install and after it. So an install for a
new site starts with no stored current theme, and it leaves none.

`site_after_install` installs the default plugins and then calls `site_install_theme`. The first
hook of a plugin install reads `current_theme`. A new site has no `_theme` option, so that read
creates a theme record for `default_template`, with the slug as its name. A probe on a new site
gave these results on 2026-11-21:

| Flow | Theme that gets `plugin_after_install` | `on_inactive` runs for | Theme records after |
|---|---|---|---|
| Installer, theme `new` | `default` | `default` | `default` (inactive), `new` |
| Admin site create, theme `default` | `default` | `default` | `default`, named `default` |
| `_theme` stored first, theme `new` | `new` | `new` | `new` |

In the first flow, `current_theme` was `default` while the `on_active` handler of `new` ran. So the
fault of `proposal.md`, "Why", also occurs on a site create, and D1 removes it there too.

## Goals / Non-Goals

**Goals:**

- `current_theme` is the theme that is installed while its `on_active` hook runs.
- `current_theme` is the theme that is uninstalled while its `on_inactive` hook runs.
- Both hold in a request with a theme preview, and that request keeps its preview after the hooks.
- `hooks_run` and the theme helpers need no change: they read `current_theme`.
- A handler that uses the theme record of its argument keeps its behavior.
- On a site create, the theme of the site gets the hooks that the default plugins fire.
- A site create runs no `on_inactive` hook, and it makes no theme record for another theme.

**Non-Goals:**

- The order of a site create. The default plugins are installed before the theme, so a plugin hook
  handler of the theme runs before its `on_active` handler.
- A guard against a second run of a handler (D4).
- A change to `Site#get_theme` or to `Theme`. A read of `current_theme` still creates a missing
  theme record with the slug as its name.

## Decisions

**D1. `site_install_theme` stores the installed theme as the current theme of the request.** It
assigns the decorated theme record to `CurrentRequest.frontend_current_theme` after it activates the
record and before it runs `on_active`. The assignment stays after the hook. The site has the new
theme from that point, so each later read in the request gets the correct theme. A request with a
theme preview is the exception (D5).

- *Alternative A: assign for the hook only, then restore the old value.* Rejected: the old value is
  the theme that the site no longer has.
- *Alternative B: `hooks_run` reads the theme slug of the site, not `current_theme`.* Rejected: the
  theme helpers keep the fault, and a theme preview loses the hooks of the preview theme.
- *Alternative C: clear the stored theme, and let the next read fill it.* Rejected: the next read
  loads a second record. A change that the handler makes on its argument is then not on
  `current_theme`.

**D2. `current_theme` wraps the record that the handler gets.** The decorator holds the same record
object. So an option or a meta that the handler writes on its argument is read from `current_theme`
with no reload.

**D3. `site_uninstall_theme` runs its hook the same way.** With no theme preview, the current theme
is already the theme that is uninstalled. The uninstall reads the theme slug of the site, which is
the slug that filled `current_theme`. The one stale case was a second install in one request, and D1
removes it.

With a theme preview, the current theme is the preview theme (D5). So both hooks run through one
private method of `CamaleonCms::SiteHelper`, which takes the theme record and a block.

**D4. Camaleon does not prevent a second run of a handler (intended).** A theme can call its own
handler directly in `on_active`, because the hook did not reach it before. With D1 the hook reaches
it, so it runs two times. A dispatch still runs a handler one time, and a guard in `hooks_run`
cannot stop a direct call. The upgrade note tells the theme developer to remove the direct call, or
to make the handler safe for a second run.

**D5. The method of D3 sets the preview theme aside while the hook runs.** The maintainer chose this
remedy on 2026-11-21. The method stores the theme record as the current theme (D1). When the object
that runs the helper has `@_current_theme`, the method sets that variable to `nil` and runs the
block.

The method restores the variable in an `ensure` clause, so a handler that raises does not end the
preview. The next read of `current_theme` gives the preview theme again, and the page renders with
it.

The method reads and writes the variable with `instance_variable_get` and `instance_variable_set`,
as `current_theme` does. It changes the variable only on the object that runs the helper. A
controller gives its variables to a view when the view starts. So a view that a handler renders
during the hook gets no preview theme, and it reads the theme of the hook.

- *Alternative A: leave the preview request as it is.* No request of Camaleon installs a theme in a
  theme preview. Rejected by the maintainer: the requirement then has an exception.
- *Alternative B: write the installed theme to `@_current_theme`.* Rejected: the preview ends in the
  middle of the request. The view lookup paths are already those of the preview theme, so the page
  renders a mix of two themes.
- *Alternative C: raise for an install in a theme preview.* Rejected: a new failure for a case that
  no user reported.
- *Alternative D: set the preview theme aside for `on_active` only.* Rejected: a hook that the
  `on_inactive` handler fires still goes to the preview theme.

**D6. `site_after_install` stores the theme of the site before it installs the default plugins.**
The maintainer chose this remedy on 2026-11-21. It writes the `_theme` option first. Each reader
then gives the same theme: the option, `Site#get_theme`, `current_theme`,
`PluginRoutes.enabled_apps` and the draw of the routes. The installer then behaves as the admin site
create already does, where the theme that is installed is the theme that the site has.

- *Alternative A: make the theme the current theme for the plugin installs only.* Rejected: the
  site still names the default theme. A handler gets two answers, and the routes of the theme of
  the site are not drawn. The default theme keeps its record and its `on_inactive` run.
- *Alternative B: install the theme before the plugins.* Rejected: an `on_active` handler that
  needs a default plugin breaks.
- *Alternative C: no change.* Rejected by the maintainer.

**D7. A site create runs no `on_inactive` hook.** The maintainer chose this on 2026-11-21. With D6
alone, the theme of the site gets its `on_inactive` hook before its `on_active` hook. The handlers
of `new`, `camaleon_first` and other themes destroy the theme record there. So a value that a plugin
hook handler stored on that record is lost.

`site_install_theme` keeps its uninstall. The steps after the uninstall move to a private method of
`CamaleonCms::SiteHelper`, and `site_after_install` calls that method. No public method changes its
arguments.

No `on_inactive` handler of the 10 themes of the sibling checkouts needs a run on a new site. It
does nothing, or it destroys the new record. In `camaleon-cms-efashion` and `cama-ecommerce-theme`
it writes `nil` to an option of the ecommerce post type.

- *Alternative A: a keyword argument, `site_install_theme(key, uninstall: false)`.* Rejected: the
  public method grows, and a host method that replaces it with one argument raises.
- *Alternative B: `site_uninstall_theme` finds out that the theme was never installed.* Rejected:
  no stored value says so. A read of `current_theme` creates the record, and D6 writes the option.
  A new mark on the record needs a backfill for each site that exists.

**D8. The install gives the theme record its name.** The first read of `current_theme` on a new site
creates the record with the slug as its name. `site_install_theme` gave the name of the theme
config only to a record that it created. Until now, an `on_inactive` handler that destroys the
record hid this for some themes. With D7, each new site gets the slug as the name.

So the private method of D7 writes the name of the theme config when the name of the record is
empty or is the slug. The custom field group form shows that name.

- *Alternative A: `Theme` reads the name of its config when its name is empty.* Rejected for this
  change: it changes each record that a read creates, also the record of a theme preview.

**D9. A site create also sets the preview theme aside.** The maintainer chose this remedy on
2026-11-21. A preview theme is a theme record of the site of the request. `current_site(site)`
clears the stored theme, but `current_theme` reads `@_current_theme` first.

So in a theme preview, the hooks of the default plugin installs went to the preview theme of the
other site. A handler then wrote to the record of that site. `site_after_install` now runs the whole
create through the method that sets the preview aside for D5.

`cama_with_current_theme` uses the same method. After the block, that method also writes the
preview theme back to `CurrentRequest`, which the view lookup reads directly.

The create gives the site of the request back in an `ensure` clause. Before, a handler that raised
left the new site as the current site of the request, with or without a preview. The maintainer
chose this fix on 2026-11-21.

- *Alternative A: name the exception in the requirement.* Rejected: it is the exception that D5
  rejected for a theme install, and the write to the record of the other site stays.
- *Alternative B: `current_site(site)` clears the preview when it changes the site.* Rejected:
  many callers use `current_site(site)`, and the switch back cannot restore the preview.

**D10. An install refuses a theme that is not installed.** The maintainer chose this remedy on
2026-11-21. The install stored the theme key and made each theme record inactive before it read
the config of the theme. With no config, it then raised `NoMethodError`. The site kept a theme with
no config, and its frontend failed until an administrator installed another theme.

The installer saved the site before that error. So the installer closed, and the operator did not
see the generated admin password. The fault was there before this change. This change added the
error for a record that has its slug as its name (D8).

Now `site_install_theme` and `site_after_install` raise `ArgumentError` before their first write.
The theme page of the admin panel shows an error, and the installer checks the theme before it
saves the site. The error is a refusal, so no default theme takes the place of the key.

The site create of the admin panel also saves the site before its install. It installs the default
theme of the system config (`default_template`), and a host can name a theme there that is not
installed. So the helper raised after the save, and the site stayed without its install. Before this
change, that create made a site with a theme that had no config. The maintainer chose on 2026-11-21
that this create also checks the theme before the save. The installer checks the default theme in
the same way for a request with no theme.

- *Alternative A: fall back to the default theme.* Rejected: it hides a wrong key or a missing gem.
- *Alternative B: guard the controllers only.* Rejected: a direct call still stores the key.
- *Alternative C: make the name line safe for a missing config.* Rejected: the site then has a
  theme with no config, and no error says so.

## Risks / Trade-offs

- [A handler that a theme also calls directly runs two times] → The upgrade note names the case and
  the two remedies. `camaleon_website` already guards its handler.
- [The handler of the theme before the install no longer gets a hook that the install fires] → That
  theme is inactive at that point. The upgrade note names the change.
- [An `on_active` handler read the theme before the install from `current_theme` on purpose] → No
  known theme does this. The `on_inactive` hook of that theme is the place for such code.
- [No request of Camaleon installs a theme in a theme preview] → In the spec, a `front_before_load`
  handler of the preview theme calls `site_install_theme`.
- [In a preview request, code after the hooks reads the preview theme] → A preview request shows the
  site with the preview theme.
- [On a site create, a plugin hook handler of the theme runs before `on_active`. An error in it
  stops the install, and the saved site stays without the rest of its install] → The default theme already has this order. The upgrade note names it.
- [A theme used `on_inactive` as a reset before `on_active` on a new site] → A new site has nothing
  to reset. The upgrade note tells the developer to do such work in `on_active`.
- [A host replaces `site_install_theme` to catch a site create] → `site_after_install` no longer
  calls it. No sibling checkout does this. The upgrade note names the change.
- [The site factory of the suite calls `site_after_install`] → The whole suite runs before the push.
