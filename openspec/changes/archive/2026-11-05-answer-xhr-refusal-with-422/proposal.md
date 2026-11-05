# Answer a refused admin save with a 422 to an XHR

## Why

The admin panel refuses a save in these cases: a custom-field value with unsafe content or with an
invalid group number, a `cama_post_decorator_class` option that names no post decorator, and a meta
or options container that is not a set of fields. The two `rescue_from` handlers of
`CamaleonCms::AdminController` answer each refusal with a redirect back and the message in a flash.

The nav menu item settings modal posts its form by XHR, and its script reads only a success. The
XHR followed the redirect and got the admin page. The script alerted that page and closed the modal
as if the save had passed. The redirected page consumed the flash, so the user never saw the
refusal, and the values of the item were not stored.

## What Changes

- A refused admin save answers by the kind of the request. A submitted form, and an XHR that
  carries the `cama_ajax_request` param (`camaleon_admin_ajax`), get the redirect back and the flash,
  as before. Any other XHR gets the message as text with a 422, and no flash.
- The nav menu item settings modal shows a 422 as a refusal and stays open. Any other failure shows
  a generic message. The spinner comes down on each outcome.
- The draft save of the post editor gets a 422 in place of the redirect. Its script reads both as a
  failed draft save, so the user sees the same message.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: a refused admin save answers by the kind of the request.
- `post-decorator-class-integrity`: a refusal from a save hook answers the same way.
- `meta-storage-integrity`: a container that is not a set of fields answers the same way.

## Impact

- `app/controllers/camaleon_cms/admin_controller.rb` (the two rescue handlers),
  `app/assets/javascripts/camaleon_cms/admin/nav_menu.js` (the modal),
  `config/locales/camaleon_cms/admin/js/*.yml` (the generic message).
- Specs: a new `spec/requests/admin/appearances/xhr_save_refusal_spec.rb` and a new
  `spec/features/admin/nav_menu_item_settings_refusal_spec.rb`.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers what changes.
- Ecosystem: no surveyed consumer posts a save that can be refused by XHR without
  `cama_ajax_request`. `docs/ai/ecosystem.md` records the survey.
