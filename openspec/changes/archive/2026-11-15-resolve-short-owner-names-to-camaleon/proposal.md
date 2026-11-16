# Proposal

## Why

A row of `Meta`, `CustomFieldGroup` or `CustomFieldsRelationship` stores the short name of its
owner class in `object_class`, such as `Post`. `CamaleonRecord.polymorphic_class_for`
gave this name to Rails first, and Rails finds it as a top-level constant. In a host app with its
own `Post` model, the `owner` of a meta of a Camaleon post was then a record of the host. The same
applies to `Site`, `Theme`, `Category`, `PostTag`, `PostType`, `NavMenuItem` and each other model
of Camaleon. A host `User` model was the owner of the metas of `CamaleonCms::User`.

## What Changes

- `CamaleonRecord.polymorphic_class_for` tries the Camaleon class of a short name first: the
  configured user class for `User`, the widget class for `Main`, `Sidebar` and `Assigned`, else
  the `CamaleonCms` model of that name.
- A name with `::`, and a short name with no `CamaleonCms` model, such as the class of a plugin,
  resolve as before.
- A `CustomFieldGroup` row can also store a placement name, such as `PostType_Post`. This name
  also resolves as before.
- `CamaleonCms::CustomFieldsRelationship#update_model_owner` touches the record that `owner`
  gives. Before, it touched a record of the `CamaleonCms` model of that name, so a widget value
  touched no record.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `meta-scope-resolution`: a requirement for the read direction, from a stored scope name to the
  owner class, and a requirement for the touch of the owner after the save of a custom-field value.

## Impact

- `app/models/camaleon_record.rb`, `spec/models/camaleon_record_spec.rb`.
- `app/models/camaleon_cms/custom_fields_relationship.rb`,
  `spec/models/custom_field_value_owner_touch_spec.rb`.
- A widget, a plugin record or a host record that `owner` gives now gets a touch after each save
  of its custom-field values. Each touch runs the `after_touch` callbacks of the record.
- A host app with a top-level class of the same name as a Camaleon model. Such a host model that
  stores Camaleon metas under its own short name now reads the Camaleon record as their owner. No
  known plugin or theme does this.
