# Design

## Context

See `proposal.md`, "Why".

## Goals / Non-Goals

**Goals:**

- A user with no `custom_fields` permission cannot read or change a custom field group through the
  custom fields controller.

**Non-Goals:**

- A change of the `list` action. The post form of each role calls it, and it checks the right of
  the user on the post.
- A change of the pages that show the fields of a record, such as the post form.

## Decisions

**D1. The role check names the one action that it leaves out.** The line is
`before_action :validate_role, except: :list`. A new action then gets the check with no more code.

- *Alternative: add `reorder` to the list of checked actions.* Rejected: the read actions stay open,
  and a new action gets no check.
- *Alternative: remove the line.* Rejected: the role check of the settings controller then covers
  `list`, and the post form of a role with no `custom_fields` permission loses its fields.

**D2. A refused request gets the answer of each refused admin request.** `AdminController` rescues
`CanCan::AccessDenied` and redirects to the dashboard with an error message.

**D3. The Custom Fields item of the Settings menu needs the permission of its pages.** The menu gave
the item to each role with the `settings` permission. After D1, a click on the item redirected such
a role with no `custom_fields` permission to the dashboard. The two menu builders now add the item
only for a role that also has the `custom_fields` permission.
