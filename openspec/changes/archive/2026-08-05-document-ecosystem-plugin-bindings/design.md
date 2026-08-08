# Design: document-ecosystem-plugin-bindings

## Why a capability rather than a document alone

A markdown inventory rots without complaint. A requirement with a named consumer does not: when a
later change proposes to escape admin menu titles, `openspec validate` and review surface the
requirement that says `camaleon-ecommerce` renders HTML in one, and the decision gets made in the
open. The inventory still exists — `docs/ai/ecosystem.md` — but it is the reference companion, not
the contract. Facts that change every time a plugin releases (last commit, version constraint) live
in the doc; contracts that the engine must honour live in the spec.

## What counts as a binding worth specifying

The survey found roughly 200 distinct call sites. Most are ordinary public API use that any Rails
engine would preserve without being told (`current_site`, `the_title`, `link_to`). Three tests
promote a binding into the spec:

1. **A reasonable refactor would break it.** Hook dispatch moving off the controller instance is a
   plausible next step of the `CurrentRequest` migration, and it would break seven plugins.
2. **The breakage is silent.** `cama_external_menu`'s role check fails *open* — restricted menus
   become publicly visible — which no test in this repository would catch.
3. **The contract is not obvious from the method signature.** That `before_upload` may replace
   `settings[:uploaded_io]` but must not change its `path` is invisible until you read the plugin
   that depends on it.

Bindings that fail all three are inventory, not requirements.

## Hook dispatch is the load-bearing contract

`hooks_run` → `_do_hook` → `send(hook, params)` on `self`. Every surveyed plugin assumes `self` is
the controller. The dependency is not incidental — it is how the extension model works:

- `camaleon_post_created_at` reads the controller ivar `@post` inside `new_post`/`edit_post` and
  interpolates it into a string, so a nil `self` state raises rather than degrading.
- `camaleon_lazy_loader` writes `response.body`, sets `@skip_lazy_loader` in one hook and reads it
  in another on the same instance, and reads `@_plugin_do_cache` — a private ivar owned by the
  bundled `front_cache` plugin.
- `camaleon_admin_ajax` writes four different `flash` variants and reads `params`.
- `cama_external_menu` calls `current_user` and suppresses a menu item by setting
  `args[:parsed_menu] = false`.

The spec therefore states the guarantee positively — hooks execute with the request's controller as
receiver — instead of leaving it as an emergent property of `send`.

## In-place mutation is the payload convention, not an accident

Core seeds a hash, runs the hook, and reads the same object back. Plugins rely on `+=`, `<<` and
`[]=` against pre-seeded keys. `camaleon_sitemap_customizer` does `args[:skip_post_ids] += …` on all
four sitemap skip lists — which is exactly the contract [#1223](https://github.com/owen2345/camaleon-cms/pull/1223)
restored when it fixed H4, and the survey confirms the plugin matches it key for key. A seeded key
that arrives `nil`, frozen, or renamed breaks the consumer at the mutation, not at a boundary.

`camaleon_lazy_loader` binds the same `on_render_sitemap` hook with an **arity-1 handler that ignores
its argument**, which pins the call shape independently of the payload: `hooks_run` must keep passing
exactly one argument.

## Two engine defects the survey exposed — recorded, not fixed

**`before_upload` runs after the content scan.** In `UploaderPipeline#upload_file` the scan gate sits
at the top and `hooks_run('before_upload', settings)` fires afterwards; the file finally persisted is
`settings[:uploaded_io]`, which a handler may have replaced. `camaleon_image_optimizer` does exactly
that, and advertises SVGO support — so an SVG cleared by `SvgContentChecker` can be rewritten before
storage. Whether the pipeline should re-scan when a hook swaps the handle, or whether `before_upload`
handlers are trusted by definition, is a security decision that belongs in the upload capability with
its own reproduction, not in a documentation change. Recorded here so the question is not lost.

The same ordering is load-bearing in the other direction: `cached_name` and `settings[:filename]` are
computed *before* the hook, so a handler that rebinds `uploaded_io` keeps the original filename only
because of that ordering. The spec states the resulting rule — a handler may replace the IO object
but must not change its `path`.

**`CamaleonCmsLocalUploader.private_file_path` does not exist.** `camaleon-download` and
`cama-stripe-donation` both call it, positionally, and feed the result to `send_file`. It is absent
from `app/uploaders/`. Both plugins are already broken against master; `cama-stripe-donation` passes
a Base64-decoded request parameter as the path, so restoring the method naively would restore a path
traversal with it. Left as an open question with the traversal noted.

## Where the survey contradicted the plan's assumptions

Four defaults in the medium-fix plan were set from core-only reasoning and the evidence reversed
them. They are recorded here because the reasoning, not just the conclusion, is what a later reader
needs:

| Question | Core-only guess | Evidence | Outcome |
|---|---|---|---|
| Escape admin menu titles? | Yes — hardening | `camaleon-ecommerce` ships an HTML title | Allowlist, not blanket escaping |
| Honour `@cama_current_user`? | Yes — SSO plugins need it | The SSO plugin uses Doorkeeper; zero writers exist | Drop the ivar read; keep the method overridable |
| Coerce the upload size limit at core read sites? | Sufficient | `cama_contact_form` reads the option itself and passes `maximum:` | Coerce in `cama_size_limit_error` instead |
| Defer the asset precompile snapshot? | Needed | Neither host app appends `assets.paths` | Document the ordering; no code change |

The pattern is worth naming: **the ecosystem constrains removals far less than expected and
hardening far more.** Eleven of the surveyed API surfaces have no consumer at all
(`update_or_create`, `find_by_key`, `unassign_category`, `cf_add_model`, `@_admin_menus`,
`on_translation`, `render prefixes:`, and the rest), while three hardening changes that looked free
would each have broken a shipped plugin. Restoration decisions can be made on the engine's own
merits; escaping, validation and permission decisions need this spec consulted first.

## Deliberately not specified

**Version constraints as a compatibility gate.** Fifteen of the twenty surveyed repositories declare
no `camaleon_cms` dependency at all, and the one explicit constraint is `>= 2.3.5`. Gating behaviour
on the consumer's declared version would protect nobody.

**Plugins that cannot load.** `camaleon_editor` and `camaleon_admin_ajax` both `include` a private
module that is published nowhere; `camaleon_editor`'s six declared hooks have no handlers in the
open-source tree. They are inventory entries, not contract sources — a core change cannot break what
does not load, and their bindings cannot be verified.

**The `select_eval` collateral.** `camaleon-cms-efashion` and `camaleon-cms-shoppy` create
`field_key: "select_eval"` fields from their activation hooks, which now raise under the permission
gate. That gate is an intentional capability decision; the themes are recorded as collateral so the
next person to see the exception knows why, and nothing here proposes to loosen it.
