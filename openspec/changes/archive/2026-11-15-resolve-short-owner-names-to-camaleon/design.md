# Design

## Context

See `proposal.md`, "Why".

## Goals / Non-Goals

**Goals:**

- A short scope name that Camaleon writes resolves to the Camaleon class, also when the host app
  has a top-level class of that name.

**Non-Goals:**

- A change of the scope names that Camaleon writes (`polymorphic_name`, the `CommonRelationships`
  scopes).
- A change of a name with `::`, or of a short name with no Camaleon model.

## Decisions

**D1. The Camaleon class comes before the top-level constant.** Camaleon writes the demodulized
name of its classes, so a short name in a Camaleon table is a Camaleon name first. Before, Rails
gave the Camaleon class only when no top-level constant of that name existed.

- *Alternative: fix only the callers that read `owner`.* Rejected: each caller must then repeat the
  lookup, and a new caller gets the host record again.

**D2. Only an Active Record class of the `CamaleonCms` namespace counts.** `CamaleonCms::Ability`
is no model, and a host app with CanCan has a top-level `Ability`. A name such as `Ability` thus
resolves as before.

**D3. `User` resolves to the configured user class.** `CamaManager.get_user_class_name` is
`CamaleonCms::User` by default and can name a host class. Before, a top-level host `User` was the
owner also when Camaleon used `CamaleonCms::User`.

**D4. A nested model gets its class from a map.** `CamaleonCms::Widget::Main` writes the scope
name `Main`, and `CamaleonCms::Main` does not exist. `CamaleonRecord::NESTED_POLYMORPHIC_CLASSES`
gives `Main` its class, and the same for `Sidebar` and `Assigned`. These three widget
models are the nested models, and each gets metas from `CommonRelationships`.

- *Alternative: a registry that each subclass of `CamaleonRecord` fills when it loads.* Rejected:
  without eager loading, a class that has not loaded is not in the registry, so the result
  depends on the load order.

## Risks / Trade-offs

- A host model that is not a Camaleon model and stores Camaleon metas under a short name of a
  Camaleon model now reads the Camaleon record as the owner. A check of the known plugins, themes
  and the `florsan` host found no such model. The upgrade note gives the case.
