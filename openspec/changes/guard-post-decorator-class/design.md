## Context

See proposal.md for the motivation. Today `Post#decorator_class` (`app/models/camaleon_cms/post.rb`)
reads `post_type.get_option('cama_post_decorator_class', 'CamaleonCms::PostDecorator')` inside a
`begin`/`rescue` that covers only the read, then calls `constantize` on whatever came back. It
overrides Draper's `Decoratable#decorator_class`, which `decorate` calls.

Post type options live in the `_default` meta as one JSON hash. Every writer of an option, whether
`set_option`, `set_options` and its alias `set_multiple_options`, the `data_options` save callback
or `delete_option`, ends in `CamaleonCms::Metas#set_meta('_default', hash)`, a plain module method
that `PostType` can override and call with `super`. `CamaleonCms::AdminController` rescues
`ActiveRecord::RecordInvalid` for custom-field value rows only and re-raises for any other record.

Constraints from `docs/security/permissions.md`: a refusal is loud; nothing stored is rewritten,
at save or at render; stored data that predates a check is reported by the scan tasks. Precedents:
custom-field structural values are held to an allowlist that applies to administrators too, and
`PostDefault.find_sti_class` enforces ancestry on a class name read from the database.

## Goals / Non-Goals

**Goals:**

- One check at the option's single write path and one at its consumer, so a writer that does not
  exist yet is covered as well.
- A resolver shared by the save check, the read and the scan, so the three cannot disagree.

**Non-Goals:**

- A permission. No role can be trusted with an arbitrary class name; the check is validity, and
  `security-capability-gating` makes a permission the last resort.
- Changing which hooks run after a save or when (a separate change).
- Repairing stored values; the scan reports them.

## Decisions

1. **The check lives in `PostType#set_meta`**, for the `_default` key, and looks at
   `cama_post_decorator_class` when the hash carries it non-blank (string or symbol key). Every
   writer funnels through that method. The alternative, checking in `set_option` and `set_options`,
   misses `set_multiple_options` (an alias bound to the concern's method when the alias was made),
   the `data_options` callback and a direct `set_meta`; a validation on `CamaleonCms::Meta` would put
   the option's grammar in a model that knows nothing of it and tax every meta write.
2. **The refusal adds an error on the post type and raises `ActiveRecord::RecordInvalid`.** In the
   admin panel that reaches the existing rescue, extended to `PostType` records, which flashes the
   message and redirects back; in code (a migration, the console, a plugin's install hook) the raise
   names the option and the value. The alternative, skipping the write with a log line, is silent:
   a plugin would believe it stored the value.
3. **What is accepted:** `value.to_s.safe_constantize` that is a `Class` and
   `<= CamaleonCms::PostDecorator`; blank clears the option. `safe_constantize` turns an unknown name
   into a refusal rather than a `NameError`; the `Class` guard matters because a constant can
   resolve to a non-module, on which `<=` raises. The resolver is one class method,
   `PostType.decorator_class_for(value)`, used by the check, the read and the scan.
4. **The read falls back rather than raising.** `PostType#post_decorator_class` returns the resolved
   class or `CamaleonCms::PostDecorator`, logging a warning when a non-blank stored value is ignored;
   `Post#decorator_class` delegates to it and keeps its rescue for a post without a post type.
   Raising at read would reintroduce, for history the operator has not cleaned up yet, the outage
   a bad stored value caused before.
5. **Reporting joins `scan_content`,** the operator's one entrypoint for what today's gates would
   refuse, as a third loop over post types naming the post type and the value.

## Risks / Trade-offs

- [A plugin writes the option before its decorator class is loadable] → Zeitwerk autoloads on
  `safe_constantize`; a class that cannot load is refused loudly at install, which is the wanted
  signal.
- [A theme or plugin stores a decorator outside the `CamaleonCms::PostDecorator` hierarchy] → the
  ecosystem survey found none (camaleon-ecommerce's inherits from it, camaleon-spree reopens the
  core class), and Draper's `decorate` needs the decorator API anyway, so such a value never worked.
- [A stored non-decorator value predating the change now renders with the default decorator] →
  the request failed before; the warning and the scan report it for cleanup.
- [`set_meta` runs for every meta write] → the check keys on `'_default'` and on the option being
  present; the cost is a hash lookup.

## Migration Plan

No schema or data change. After deploying, an operator runs
`bundle exec rake camaleon_cms:security:scan_content` to list post types whose stored decorator
option is now ignored. Rollback is reverting the release.
