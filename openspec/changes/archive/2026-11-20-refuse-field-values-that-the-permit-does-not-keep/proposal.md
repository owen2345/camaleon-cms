# Refuse field values that the permit does not keep

## Why

`CamaleonCms::Admin::CustomFieldsConcern#cama_permitted_field_options` is the permit that all admin
custom-field saves share. It keeps the `values` of a field as a hash keyed by index or as a list of
scalars. It drops `values` in any other shape, such as a list of hashes, a nested list or a scalar.
The entry of the field stays in the payload with its `id`.

`set_field_values` deletes each stored value of the record before it writes the payload. So an entry
that lost its `values` removes the stored values of its field. The save answers with its usual
redirect and its success notice. The admin sees no sign that the field is now empty.

A field entry that is a scalar or a list has the same effect. The permit leaves it out of the
payload, and a save with another valid entry removes the stored values of that field.

No admin form of Camaleon sends such `values` or such an entry. A plugin form, a script or a client
with a defect can send them.

## What Changes

- The permit raises `CamaleonCms::Admin::CustomFieldsConcern::UnusableFieldValues` for the entry of an
  allowed slug with `values` in a shape that it does not keep.
- The permit raises the same error for the entry of an allowed slug that is a non-empty scalar or a
  list.
- `CamaleonCms::AdminController` answers that error as it answers a refused custom-field value. A
  submitted form, and an XHR with the `cama_ajax_request` param, get a flash message and a redirect
  back. Any other XHR gets the message as text and a 422.
- The stored values of the record stay.
- An entry with no `values`, with `nil` or with an empty `String` still removes the stored values of
  its field. The form sends such an entry for a checkboxes field with no option checked.
- `docs/upgrading-to-2.9.5.md` and `docs/ai/ecosystem.md` describe the change for a plugin developer.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-filtering`: a new requirement gives the refusal. The scenario of a list of
  non-scalars says that the save is refused.
- `custom-field-value-rejection`: the list of the cases of a refused admin save names the refusal.

## Impact

- `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb`: the error class and the check.
- `app/controllers/camaleon_cms/admin_controller.rb`: the `rescue_from` of the error.
- `config/locales/camaleon_cms/admin/en.yml`: the message `values_unusable`.
- A plugin controller that calls the permit gets the refusal with no change, when it inherits
  `CamaleonCms::AdminController`.
- No change for a payload that an admin form of Camaleon sends.
