## Context

See proposal.md for the motivation. Today `Post#decorator_class` (`app/models/camaleon_cms/post.rb`)
reads `post_type.get_option('cama_post_decorator_class', 'CamaleonCms::PostDecorator')` inside a
`begin`/`rescue` that covers only the read, then calls `constantize` on whatever came back. It
overrides Draper's `Decoratable#decorator_class`, which `decorate` calls.

Post type options live in the `_default` meta as one JSON hash. Every writer of an option, whether
`set_option`, `set_options` and its alias `set_multiple_options`, the `data_options` save callback
or `delete_option`, ends in `CamaleonCms::Metas#set_meta('_default', options)`, a plain module method
that `PostType` can override and call with `super`, and each passes the whole merged options, not
only the key it changes. `CamaleonCms::AdminController` rescues `ActiveRecord::RecordInvalid` for
custom-field value rows only and re-raises for any other record.

Constraints from `docs/security/permissions.md`: a refusal is loud; nothing stored is rewritten,
at save or at render; stored data that predates a check is reported by the scan tasks. Precedents:
custom-field structural values are held to an allowlist that applies to administrators too, the
content gates leave an unchanged pre-gate value editable, and `PostDefault.find_sti_class` enforces
ancestry on a class name read from the database.

## Goals / Non-Goals

**Goals:**

- One check where every option writer ends and one at its consumer, so a writer that does not exist
  yet is covered as well.
- A resolver shared by the save check, the read and the scan, so the three cannot disagree.

**Non-Goals:**

- A permission. The option is configuration, and a class outside the `CamaleonCms::PostDecorator`
  hierarchy cannot work as a post decorator for any role, administrators included, so the check is
  validity rather than a capability to grant; `security-capability-gating` makes a permission the last
  resort.
- Changing which hooks run after a save or when (a separate change).
- Repairing stored values; the scan reports them.
- Checking rows written around `set_meta`, such as an importer creating `CamaleonCms::Meta` rows
  directly; the read and the scan cover them.

## Decisions

1. **The check lives in `PostType#set_meta`**, for the `_default` key, and reads
   `cama_post_decorator_class` from the options as `set_meta` will store them: a Hash in either key
   form (the one written last wins), `ActionController::Parameters` or a JSON string. Every writer
   funnels through that method. It refuses a value only when it differs from the stored one: writers
   pass the whole merged options, so refusing a stored value the check would refuse (written before
   the check, left by a removed plugin, imported) would lock every other option of the post type,
   which the content gates avoid by leaving unchanged pre-gate values editable. The alternative,
   checking in `set_option` and `set_options`, misses `set_multiple_options` (an alias bound to the
   concern's method when the alias was made), the `data_options` callback and a direct `set_meta`; a
   validation on `CamaleonCms::Meta` would put the option's grammar in a model that knows nothing of it
   and tax every meta write.
2. **The refusal adds an error on the post type and raises `ActiveRecord::RecordInvalid`.** In the
   admin panel that reaches the existing rescue, extended to `PostType` records, which flashes the
   message and redirects back for a submitted save; a refusal that comes while serving a GET or HEAD
   request is raised again instead, since a redirect would only reach another page that refuses. In
   code (the console, a plugin's install hook) the raise names the option. A value passed in `data_options` is written by the save callbacks after the INSERT, where
   ActiveRecord's `save` would turn the raise into `false` and an enclosing transaction would keep the
   row, so the same check also runs as a validation: the save is refused before anything is written,
   and `create!` and `update!` raise. The error quotes the value only when it is a class name, cut to
   100 characters, because the admin panel renders flashes raw and carries them in the session cookie;
   its text is an en.yml key, as the other gate refusals. A refusal drops the memoized options and a
   loaded metas association, which the writers had already changed or which `set_meta` never updates.
   The alternative, skipping the write with a log line, is silent: a plugin would believe it stored the
   value.
3. **What is accepted:** a blank value, which clears the option and resolves to the default
   decorator, or `value.to_s.safe_constantize` that is a `Class` and `<= CamaleonCms::PostDecorator`.
   `safe_constantize` turns an unknown name into a refusal rather than a `NameError`, but still raises
   for a path through a constant that is not a module and for a decorator file that fails to load, so
   the resolver answers no class for those too; the `Class` guard matters because a constant can
   resolve to a non-module, on which `<=` raises. The resolver is one class method,
   `PostType.decorator_class_for(value)`, used by the check, the read and the scan, and the blank rule
   lives in it.
4. **The read falls back rather than raising.** `PostType#post_decorator_class` returns the resolved
   class or `CamaleonCms::PostDecorator`, logging a warning once per request for each post type and
   ignored value, since every decorated post asks; `Post#decorator_class` delegates to it and, when
   the lookup fails (an options row that is not a JSON object), falls back to the default and logs the
   error. Raising at read would reintroduce, for history the operator has not cleaned up yet, the outage
   a bad stored value caused before.
5. **Reporting joins `scan_content`,** the operator's one entrypoint for what today's gates would
   refuse, as a third loop over post types, their metas preloaded, naming the post type and the value;
   a post type whose options cannot be read is listed and the scan goes on.

## Risks / Trade-offs

- [A plugin writes the option before its decorator class is loadable] → Zeitwerk autoloads on
  `safe_constantize`; a class that cannot load is refused loudly at install, which is the wanted
  signal.
- [A theme or plugin stores a decorator outside the `CamaleonCms::PostDecorator` hierarchy] → the
  ecosystem survey found none (camaleon-ecommerce's inherits from it, camaleon-spree reopens the
  core class), and Draper's `decorate` needs the decorator API anyway, so such a value never worked.
- [A stored non-decorator value predating the change now renders with the default decorator] →
  the request failed before; the warning and the scan report it for cleanup, and it no longer blocks
  writing the post type's other options.
- [`set_meta` runs for every meta write] → the check keys on `'_default'`; for it the options are
  serialized once more to read the option as stored, and the stored row is read only for a value the
  resolver refuses.

## Migration Plan

No schema or data change. After deploying, an operator runs
`bundle exec rake camaleon_cms:security:scan_content` to list post types whose stored decorator
option is now ignored. Rollback is reverting the release.
