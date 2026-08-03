# Design: permission-gated-upload-scanning

## Why a role permission rather than a better path predicate

The obvious narrower fix for the bypass is to keep the already-published exemption but require the
output extension to match the source extension, so a `.svg` cannot become a `.html` unscanned.
That closes the demonstrated path, but it leaves the exemption answering an authorization question
with a filesystem test, and the next caller-controlled input that reaches the output name reopens
it. It also keeps two different notions of "trusted" in the uploader — one for paths, one for
roots — with nothing tying them together.

Camaleon already had the right shape twice over: `post_content_unfiltered_html` decides whether
`Post#content` is sanitized, and `contact_form_unfiltered_html` decides whether a contact form save
carrying raw HTML is refused. Both are role permissions, both are held only by administrators by
default, and both fail closed when no request user is available. Making uploads the third member of
that family means one concept to reason about, one place for an operator to look, and a decision
that does not depend on where a file happens to sit.

## Why a manager permission, not a post-type one

`post_content_unfiltered_html` lives in `ROLES[:post_type]` because post content belongs to a post
type and the grant is per type. An upload has no post type — the media library is site-wide — so
the permission belongs in `ROLES[:manager]` alongside `media` itself and
`contact_form_unfiltered_html`.

That placement also gives the correct default for free. `Site#set_default_user_roles` seeds
`_manager_` metas for exactly one role, `admin` (which is also `term_group: -1`, so it is not
editable), and administrators already satisfy any permission through `can :manage, :all`. Editor,
Contributor and Client are seeded with no manager metas at all, so none of them acquire the new
permission — no exclusion branch is needed, unlike the explicit `next if value[:key].to_s ==
'post_content_unfiltered_html'` guard the Editor post-type seeding requires.

Existing installs need no migration for the same reason: a role whose stored `_manager_` meta
predates this change simply has no `media_unfiltered_upload` key, which reads as not granted.

## Where the check lives

`cama_trusted_for_unfiltered_upload?` goes in `CamaleonCms::UploaderContentSecurity`, next to the
scanners it gates, and mirrors `Post#trusted_for_unfiltered_html?` line for line: read
`CurrentRequest.user` and `CurrentRequest.site`, return false if either is blank, otherwise ask
`CamaleonCms::Ability`. Using `CurrentRequest` rather than a controller method keeps the predicate
usable from `UploaderPipeline`, which is included into controllers, jobs and plugin code alike.

It is deliberately **not** memoized. The crop flow evaluates it twice (once in `cama_tmp_upload`,
once in `upload_file`), which costs two role-meta lookups on an operation that is already doing
file I/O and image processing. An ivar memo would have to be invalidated whenever `CurrentRequest`
changes, and the object it would hang on is sometimes a long-lived plugin helper rather than a
per-request controller. `Post#trusted_for_unfiltered_html?` makes the same call.

The `rescue StandardError` returning false matters: `Ability#initialize` dereferences the site for
non-admin users and reads role metas, so malformed meta must fail closed rather than abort the
upload with a 500.

## Ordering: permission first, scan second

The gate reads `!cama_trusted_for_unfiltered_upload? && content_unsafe?(...)`. Checking the
permission first means a trusted upload never reads the file for scanning purposes at all. This is
the opposite order from `Post#sanitize_content`, which checks `content.blank?` before building an
Ability — there the cheap test is the content test, here it is the permission test, because the
scan reads the whole file.

## Why the SVG bans are unconditional

`SvgContentChecker` only ever runs on uploads that are being scanned, and after this change an
upload is scanned exactly when the uploader lacks the permission. So the checker does not need a
`strict:` parameter to distinguish trusted from untrusted callers — the trusted caller never
reaches it. Adding `form meta base style link` straight to `BANNED_TAGS` keeps one list, one
meaning, and no branch that could be called with the wrong argument.

`form`, `meta`, `base`, `style` and `link` are all valid SVG or valid inside SVG, and none of them
executes script by itself. They are banned because an SVG is served inline from the site origin and
these five are the elements that turn a passive image into something that can navigate
(`meta http-equiv=refresh`, `base href`), collect input (`form`), or pull in remote styling
(`link`, `style`) — the same list `ContentSecurity::BLOCKED_ELEMENTS` already refuses in every
non-SVG upload. Aligning the two rulesets is what removes the rename asymmetry the bypass depended
on, independently of the permission gate.

`foreignObject` and `handler` stay banned for the reason #1226 gave, and `animate`/`set` stay
allowed for the reason #1226 gave — the SMIL vector is the `onbegin`/`onend`/`onrepeat` attribute,
which the element-agnostic `on*` rule rejects wherever it appears.

## What this does not do

It does not add a server-side extension allowlist. `settings[:formats]` still defaults to `'*'` and
still arrives from `params[:formats]`, so a user who holds `media_unfiltered_upload` can still
upload a `.html` file and have it served same-origin — that is what the permission means, and it is
why it is `color: 'danger'` in the role editor and why no default role but `admin` holds it. The
extension-policy work described in the `scoped-upload-roots-and-scan-narrowing` design remains the
follow-up; this change removes the *unauthenticated-by-design* route to the same outcome.
