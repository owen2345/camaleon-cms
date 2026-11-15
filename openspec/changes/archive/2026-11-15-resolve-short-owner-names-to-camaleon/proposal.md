# Proposal

## Why

A row of `Meta`, `CustomField`, `CustomFieldGroup` or `CustomFieldsRelationship` stores the short
name of its owner class in `object_class`, such as `Post`. `CamaleonRecord.polymorphic_class_for`
gave this name to Rails first, and Rails finds it as a top-level constant. In a host app with its
own `Post` model, the `owner` of a meta of a Camaleon post was then a record of the host. The same
applies to `Site`, `Theme`, `Category`, `PostTag`, `PostType`, `NavMenuItem` and each other model
of Camaleon. A host `User` model was the owner of the metas of `CamaleonCms::User`.

## What Changes

- `CamaleonRecord.polymorphic_class_for` tries the Camaleon class of a short name first: the
  configured user class for `User`, else the `CamaleonCms` model of that name.
- A name with `::`, and a short name with no `CamaleonCms` model, such as the class of a plugin,
  resolve as before.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `meta-scope-resolution`: a requirement for the read direction, from a stored scope name to the
  owner class.

## Impact

- `app/models/camaleon_record.rb`, `spec/models/camaleon_record_spec.rb`.
- A host app with a top-level class of the same name as a Camaleon model. Such a host model that
  stores Camaleon metas under its own short name now reads the Camaleon record as their owner. No
  known plugin or theme does this.
