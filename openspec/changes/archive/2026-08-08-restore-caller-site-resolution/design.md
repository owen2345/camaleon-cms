# Design: restore-caller-site-resolution

## The resolution order

`SiteHelper#current_site` resolves in precedence order, each winner short-circuiting:

1. an explicit `site` argument;
2. the `$current_site` global;
3. **a caller-set `@current_site` instance variable** — restored here;
4. the memoized `CurrentRequest.site`;
5. otherwise compute from `PluginRoutes.get_sites` (single-site) or the request host (multisite), then
   memoize into `CurrentRequest.site`.

Step 3 is what #1177 dropped. Its placement between 2 and 4 is load-bearing: a background sender assigns
`@current_site` for the site it is mailing about, and that must win over whatever site the current
request (if any) already memoized into `CurrentRequest.site`. Putting it after step 4 would let an
in-request `deliver_now` for site B resolve against the request's site A.

## Why the ivar, not only CurrentRequest

`HtmlMailer` (and other senders) assign `@current_site` directly — that is the seam they already use, and
`CurrentRequest.site` is deliberately left blank in a job so per-request state does not leak across
deliveries. Reading the ivar honors the existing contract without asking every sender to learn a new one.
The check uses `instance_variable_defined?(:@current_site)` — matching `current_theme`'s existing
`instance_variable_defined?(:@_current_theme)` guard — so an object that never set it is untouched.

The branch writes `CurrentRequest.site = @current_site` before returning, keeping the memo consistent for
any later `current_site` call in the same delivery.

## Why a plain method still

`ecosystem-plugin-bindings` records that `camaleon-spree` reopens `CamaleonCms::SiteHelper` to replace
`current_site` (delegating to Spree). The fix stays an ordinary instance-method edit so that override
keeps winning; it does not move resolution into a prepended module or an `ActiveSupport::CurrentAttributes`
reader.

## Scope

One branch restored in one method. No change to the single-site path, the compute-from-request path, or
the `current_site(site)` setter. The finding is a straight regression; the reproducer is the fix's proof.
