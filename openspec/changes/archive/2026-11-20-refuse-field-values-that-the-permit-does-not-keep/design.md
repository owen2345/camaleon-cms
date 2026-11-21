# Design

## Context

The shared permit keeps `values` in two shapes (`permit-array-field-values`, D1). The change
`keep-the-drop-of-a-list-of-non-scalar-values` kept the drop of each other shape. It left one effect
open: an entry with no usable `values` removes the stored values of its field.

The permit sets the `id` of each allowed slug after the Rails permit. So the entry of a slug stays
in the payload when the Rails permit drops its `values`. `set_field_values` returns early only for a
blank payload. For any other payload, it deletes each stored value of the record. Then it writes a
row only for an entry with values.

An entry with no `values` is also what the form sends. The partial `custom_fields/_render` renders
the hidden inputs `[id]` and `[group_number]` for each field. A checkboxes field with no option
checked sends only those two inputs. The delete before the write is how the save clears that field.

## Goals / Non-Goals

**Goals:**

- A save with `values` that the permit does not keep removes no stored value.
- The admin, or the client, gets a message that the save failed.
- A checkboxes field with no option checked still clears.

**Non-Goals:**

- A new `values` shape in the permit.
- The policy for a `field_options` param or a group that is not a set of fields. The permit still
  drops each of them with no message (D6).
- The two `set_field_values` calls of `SettingsController#save_theme`.

## Decisions

**D1. The save is refused.** The maintainer decided this on 2026-11-20. The alternatives:

- *Skip the write of all custom-field values, with no message.* Rejected: the stored values stay, but
  the save also drops the valid values of the same form, and the notice reports success.
- *Leave the delete and document it.* Rejected: a defect of a client deletes stored data with no
  message.
- *Remove only the entry from the payload.* Rejected: `set_field_values` deletes each stored value of
  the record, so the field loses its values in the same way.

The refusal does not limit what a trusted admin can store. The permit never stored `values` in such a
shape. The refusal only replaces a silent delete with a message.

An entry with an invalid group number has the same policy. The filter keeps a group number that is a
list or a hash, so that its validation refuses the save.

**D2. The permit raises, and `AdminController` answers.** The permit raises `UnusableFieldValues`, an
`ArgumentError` that holds the slug. `AdminController` rescues it and calls `refuse_admin_save`, as
for `CamaleonCms::Metas::InvalidContainer`. The error is raised again for a GET or HEAD request. The
alternatives:

- *Each controller reports the refusal.* Rejected: nine controllers of Camaleon call the permit, and
  released plugins call it too. A plugin controller that inherits `AdminController` gets the answer
  of D2 with no change.
- *`set_field_values` refuses the shape.* Rejected: the themes and plugins that pass raw params to
  `set_field_values` store a list of hashes as JSON values. The model must keep that.

The permit raises before `set_field_values` runs, because each caller passes its result to that
method. So the delete does not run.

**D3. No `values`, `nil` and an empty `String` hold no value.** The save clears the field, as before.
The check does not call `blank?`. A `String` of spaces is a scalar that the permit dropped, so the
save is refused.

**D4. A refused save keeps what the action stored before the permit.** This is the rule of a refused
custom-field value (the comment of `rescue_from ActiveRecord::RecordInvalid` in `AdminController`).
The post save calls the permit inside its transaction, so it stores nothing. Each other save, a
draft save included, keeps the attributes, metas and options that it stored before the custom-field
values.

The theme save writes two payloads, `theme_fields` and then `field_options`. Each write deletes the
stored values of the theme first. So the theme save runs both permits before its first write, and a
refusal of either payload keeps the stored values.

**D5. A field entry that is a scalar or a list is refused too.** The maintainer decided this on
2026-11-20, after a probe. The permit left such an entry out of the payload (`field_options[0][colors]=foo`).
A save with another valid entry then removed the stored values of that field, and it reported
success.

The permit now raises `UnusableFieldValues` for such an entry of an allowed slug. `nil` and an empty
`String` raise no error, as in D3.

A save that renders its form again before the permit runs does not change. Examples are a post save
with a refused param and a category save with a failed validation.

**D6. A malformed param or group keeps its policy.** The permit drops a `field_options` param or a
group that is a scalar or a list. It raises no error for them. The requirement "A non-hash
field-options payload is ignored, not fatal" gives that policy, and a released plugin can rely on it.
A list or a scalar names no slug, so the permit cannot tell which fields the group held.

## Risks / Trade-offs

- [A plugin controller that does not inherit `AdminController` calls the permit] → the error is not
  rescued, and the request answers with a 500. No surveyed controller does this: the permit is a
  private method of a concern for admin controllers.
- [A plugin form sends `values` in a shape that the permit does not keep] → its save now fails with a
  message. Before, the save removed the stored values of the field. `docs/upgrading-to-2.9.5.md`
  gives the two shapes that the permit keeps.
- [The host app raises for an unpermitted parameter] → Rails raises
  `ActionController::UnpermittedParameters` for such `values` first. The delete does not run either.
  Rails also raises that error for a `values` of `nil` or an empty `String`, so such a host app
  clears no field (intended, as before).
