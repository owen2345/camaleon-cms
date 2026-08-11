## Why

`Admin::Settings::CustomFieldsController#list` is a read-named action routed as GET, but it also writes:
`post.update_categories(params[:categories])`. CSRF protection does not cover GET, and the
SameSite=Lax auth cookie rides a top-level navigation, so a bare
`GET /admin/settings/custom_fields/list?post_id=42` from an attacker page performs the write — and
because an omitted `categories` param resolves to `[]`, `update_categories` deletes every one of post
42's category relationships. (`Array#to_i` is monkeypatched to `collect(&:to_i)`, so `[].to_i == []`
and the destroy path runs rather than raising.) This is audit finding **M6** — "the worst" of the
destructive-over-GET routes, because a read-named action silently destroys data.

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A. Reproduced against the unfixed branch: a post with one category,
then `GET .../custom_fields/list?post_id=<id>` with no `categories` param drops the post's categories to
`[]`. The reproduction spec fails without the guard (verified by stashing it).

## What Changes

- The category write in `#list` runs only on a **non-GET** request (`unless request.get?`), so a GET
  renders the current fields without mutating the post, and the write is subject to
  `protect_from_forgery` on POST.
- The route accepts POST as well as GET (`match 'list', via: %i[get post]`), matching its POST siblings
  `get_items` and `reorder`.
- The two existing `custom_fields_spec` cases that exercised the write are moved to POST; a new request
  spec proves a GET no longer writes and a POST still does.

## Out of scope

- **The other destructive-over-GET routes** the audit lists under M6 (post trash/restore, comment
  status toggle, widget/nav-item delete, plugin toggle/upgrade, impersonate, `crop`). Moving each off
  GET is a larger, UI-touching change (links → `data-method`/forms); this PR closes the one confirmed,
  read-named, data-destroying vector. The rest stay tracked under M6.
- **`#list`'s lack of an explicit `authorize!`** (it is reachable by any signed-in user) is a separate,
  lower-severity concern and is unchanged here.
