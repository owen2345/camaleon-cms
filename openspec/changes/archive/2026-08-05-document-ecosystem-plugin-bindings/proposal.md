# Proposal: document-ecosystem-plugin-bindings

## Why

`AGENTS.md` states that most plugins and themes live in separate gems and that "a public helper's
return contract cannot be verified from this repo alone". That warning has no artifact behind it:
nothing in the repository records *which* extension points external code actually binds to, so every
compatibility decision is made blind. The 2026-08-03 regression audit's medium findings each carry a
"restore, or document as intended?" question that cannot be answered from this repo.

Twenty-two ecosystem repositories were surveyed for this change — the sixteen plugins and four
themes named in `README.md` plus the two host applications that run them. The survey answers those
questions with evidence, and several answers contradict what the repository would have guessed:

- **`post_type_list_taxonomy` is live-broken.** `camaleon-ecommerce` calls the two-argument form in
  its admin products index; on master those taxonomy columns render empty.
- **Admin menu titles carry HTML in the wild.** `camaleon-ecommerce` renders an order count as
  `<span><small class='label label-primary'>…`, so escaping titles unconditionally degrades a
  shipped plugin's sidebar.
- **`@cama_current_user` has no external writer.** The SSO plugin (`camaleon_oauth`) signs users in
  through Doorkeeper and `login_user_with_password`, never through the ivar. What one plugin does
  need is that `CamaleonCms::SessionHelper#cama_current_user` stay overridable by module reopening.
- **`before_upload` runs after the content scan.** `camaleon_image_optimizer` rewrites the file and
  rebinds `settings[:uploaded_io]` after `content_unsafe?` has already cleared the original bytes.

None of this is derivable from the code in this repository, and all of it decays silently as the
ecosystem moves. It belongs in OpenSpec, where a requirement can be checked.

## What Changes

- A new `ecosystem-plugin-bindings` capability records the extension surface external plugins and
  themes bind to, as requirements with named consumers. Each requirement states a contract the
  engine must keep and cites the repository that depends on it, so a future change that would break
  one is caught while it is still a proposal.
- The requirements cover: hook dispatch on the controller instance, in-place mutation of hook
  payloads, the four admin-menu registration entry points, plugin asset helper arities, the
  `PluginRoutes` read surface consumed at route-draw time, the uploader option and return-value
  contract, `cama_send_email` option passthrough, and session-helper overridability.
- `docs/ai/ecosystem.md` carries the survey inventory — every repository, its declared Camaleon
  constraint, last activity, and what it binds — as the reference companion to the spec. `AGENTS.md`
  gains a pointer to it in the per-task loading table.
- No engine code changes. This change is documentation and specification only.

## Capabilities

### New Capabilities

- `ecosystem-plugin-bindings`: the external extension contract — what plugins and themes bind to,
  which consumer depends on each binding, and what the engine must therefore preserve.

## Impact

- `openspec/specs/ecosystem-plugin-bindings/spec.md` (new capability)
- `docs/ai/ecosystem.md` (new reference inventory)
- `AGENTS.md` (§5 loading table gains the ecosystem row)

**Explicitly not in scope.** This change fixes nothing. The regression-audit medium findings whose
disposition it informs — `post_type_list_taxonomy` (M23), admin menu title escaping (M22), the
legacy-ivar reads (M16/M20/M21), the upload size limit (M26) — are fixed in their own changes. Two
defects the survey found in the engine are recorded here as open questions rather than fixed:
the `before_upload` scan-ordering seam, and the absence of `CamaleonCmsLocalUploader.private_file_path`
that two plugins call.
