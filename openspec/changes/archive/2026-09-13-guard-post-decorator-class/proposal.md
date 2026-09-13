# Guard the post decorator class option

## Why

`Post#decorator_class` loads the class named by a post type's `cama_post_decorator_class` option
with `constantize` and no check, while post type options are a free-form store that plugin and
theme hooks write from request params (camaleon-cms-seo did so until its PR #53). A settings
manager could therefore name any loadable class and have it decorate every post of the type,
substituting its rendering or breaking every page that renders those posts. Core's own allowlist of
post type options protects only core's writer; the check belongs at the option's save and at its
consumer, so every writer, present and future, is covered.

## What Changes

- A post type's `cama_post_decorator_class` option is held to an allowlist for everyone,
  administrators included: a value that does not name a subclass of `CamaleonCms::PostDecorator` is
  refused at save with an error naming the option and the value, and the stored options are left as
  they were. A blank value clears it.
- A post decorates with the named class only when it is such a subclass; otherwise, including a
  stored value written before this change, it decorates with the default decorator and the ignored
  value is logged. A bad stored value can no longer take every page of the type down.
- `rake camaleon_cms:security:scan_content` also lists post types whose stored decorator option
  would be refused today.
- The admin panel surfaces the refusal of an option written by a post type save hook as a flash
  error instead of a server error.
- `docs/ai/ecosystem.md` records camaleon-cms-seo's current binding: its hooks store only its six
  SEO options.

## Capabilities

### New Capabilities

- `post-decorator-class-integrity`: what a post type's decorator class option may name, how a
  refusal surfaces, how a post resolves its decorator, and how stored values that predate the check
  are reported.

### Modified Capabilities

None. `security-capability-gating` is cited, not modified: this is a validity check that applies to
every role, not a per-role permission, because a class name loaded as code has no safe subset a role
could be trusted with beyond the decorator hierarchy, and the option is configuration, not authored
content. `ecosystem-plugin-bindings` is unaffected: camaleon-ecommerce, the one surveyed consumer
that writes the option, names a `CamaleonCms::PostDecorator` subclass and keeps working.

## Impact

- Code: `app/models/camaleon_cms/post_type.rb` (the check and the decorator resolution),
  `app/models/camaleon_cms/post.rb` (`decorator_class` delegates to the post type),
  `app/controllers/camaleon_cms/admin_controller.rb` (the refusal as a flash error),
  `lib/tasks/unsafe_stored_content.rake` (the report).
- Specs: a request reproduction under `spec/requests/security/`, a model spec for the option, and
  the scan task spec.
- Docs: `docs/security/permissions.md`, `docs/upgrading-to-2.9.5.md`, `docs/ai/ecosystem.md`,
  `CHANGELOG.md`.
- Plugins and themes: one that stores a class outside the decorator hierarchy now gets an error at
  save instead of a later crash at render; none was found in the ecosystem survey.
