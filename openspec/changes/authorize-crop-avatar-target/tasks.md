# Tasks

Ordered reproduction-first (AGENTS.md: a vulnerability fix MUST include a test that reproduces the
vulnerability). Test/impl tasks cite the `avatar-target-tenancy` delta requirement or scenario they
satisfy.

## 1. Preparation & reproduction

- [x] 1.1 Confirm work is on the security branch already cut for this
  (`claude/media-crop-authorization-18afc1`); follow docs/ai/workflows.md Phase 1 if a fresh branch is
  needed.
- [x] 1.2 Add a reproducing request spec: a caller holding `:manage, :media` but **not**
  `:manage, :users` POSTs `/admin/media/crop` with `saved_avatar` naming **another** same-site user.
  Assert the target's avatar is unchanged (the write is denied). Run it and confirm it **FAILS** on
  current code — this is the reproduction. (Delta scenario: "A media-only caller is denied another
  user's avatar".) Prefer a request spec over a controller spec; do not stub `:manage, :users`.
  → Proven: with the fix shelved, the denial/oracle examples went red (302 expected, 200 got); the
  self/manager guards stayed green.

## 2. Implement the authorization (make the reproduction pass)

- [x] 2.1 In `MediaController#crop`, **before** `cama_tmp_upload` (right after the URL-error guard),
  authorize the avatar target from the parameter: when `params[:saved_avatar]` is present and does not
  equal `cama_current_user.id`, call `authorize! :manage, :users`. Decide from the parameter, before
  any `current_site.users` lookup, so there is no same-site existence oracle and no upload/crop work on
  a denied request. (Delta requirement: "The crop avatar target is authorized as self or by a user
  manager".)
- [x] 2.2 Leave the existing write intact — `current_site.users.find_by(id: params[:saved_avatar])
  &.set_meta('avatar', res['url'])` — so the tenancy no-op is preserved for an authorized caller and
  the self path still writes. Do not add a `may_edit_credentials?` check: avatar is profile meta, not a
  credential (design Decision 5).
- [x] 2.3 Run the spec from 1.2 and confirm it now **passes**. Confirm a plain crop (no `saved_avatar`)
  still returns the cropped url and performs no user-management check. (Delta scenario: "A plain crop
  is unaffected".) → 6/6 green; plain-crop covered by `crop_spec.rb`.

## 3. Reconcile the existing specs with the new contract

Do NOT keep these green by widening the caller's permissions or stubbing `:manage, :users` — the
media-only caller staying media-only IS the reproduction. Change the **assertions**, not the setup.

- [x] 3.1 `spec/requests/security/crop_avatar_target_scope_spec.rb`, example *"still sets the avatar for
  a user in the current site"* (was ~line 48): **flipped to assert denial** — the media-only caller
  posting `saved_avatar: member.id` for another same-site `member` is denied and `member`'s avatar is
  unchanged.
- [x] 3.2 Same file, example *"does not set an avatar on a user outside the current site"* (was ~line
  40): the media-only caller is now denied (not a silent no-op); asserts the victim's avatar is
  unchanged. File header comment rewritten to describe the object-level boundary alongside tenancy.
- [x] 3.3 Added a `:manage, :users`-holding caller context demonstrating the tenancy behavior the
  media-only caller can no longer reach: a foreign-site `saved_avatar` leaves the avatar unchanged with
  no error, and a same-site target is written. (Delta scenarios: "A foreign user's avatar is not
  written", "A same-site user's avatar still updates", "A user manager writes another user's avatar".)
- [x] 3.4 Added a **self-avatar** example: a media-only caller posting `saved_avatar` equal to their own
  id has their avatar written, with no `:manage, :users` required. (Delta scenario: "A caller writes
  their own avatar".)
- [x] 3.5 Added the **oracle** assertion: a not-authorized caller is denied identically for a same-site
  id, a foreign id, a nonexistent id, and a non-numeric value (all 302). (Delta scenario: "Denial does
  not reveal whether the target exists".)
- [x] 3.6 Confirmed the unaffected specs stay green without edits: `crop_spec.rb` (its
  `saved_avatar: admin_user.id` is self) and `admin_destructive_get_verbs_spec.rb` (admin + self) —
  40 examples, 0 failures.

## 4. Optional hardening (design Open Question — decide with maintainer, do not assume)

- [x] 4.1 (Optional) Coerce `saved_avatar` to a scalar before the self-comparison and lookup, mirroring
  `UsersController#user_id_param`, so an array-shaped `saved_avatar[]` cannot reach `find_by(id: [...])`.
  → **Decided: skipped for this PR.** The array case already fails closed (an array never equals
  `cama_current_user.id`, so it requires `:manage, :users`; a media-only caller — even for their own id
  in array form — is denied). Pure defense-in-depth, no security need; left as a trivial follow-up.

## 5. Docs & changelog

- [x] 5.1 Added a note to `docs/security/permissions.md` (end of "The admin role" section): the base
  boundary — editing another user's account requires `:manage, :users` — holds at every write path, and
  `media#crop`'s `saved_avatar` write enforces it, so the media library cannot be used to bypass
  user-management. Fills a real gap (the doc previously stated only the admin-specific exceptions).
- [x] 5.2 Added a short CHANGELOG entry: lead paragraph + an upgrader note for the narrow breaking
  change (a role with `:manage, :media` but not `:manage, :users` can no longer set other users'
  avatars via crop). Credits Guilherme Facini; links #1267 as the cross-site half. **PR link to be
  filled once the PR is opened.**

## 6. Verify (CI parity, AGENTS.md §4)

- [x] 6.1 `bin/rubocop -A` on touched files only — run **before** the final spec run; fixed two
  `RSpec/ContextWording` offenses (contexts now start with `when`). Clean.
- [x] 6.2 `bin/rspec` for the affected specs — the avatar spec (6/6) plus a `spec/requests/security` +
  `spec/requests/admin/media_controller` sweep (500 examples, 0 failures). **Run the full suite before
  pushing.**
- [x] 6.3 `bin/brakeman --no-pager` — 0 warnings, 0 errors.
- [x] 6.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — loads cleanly.

## 7. Verify against artifacts & archive

- [x] 7.1 Run `/opsx:verify` to confirm the implementation matches proposal, specs, and design.
  → Passed: 2/2 requirements implemented, 7/7 scenarios tested, all 6 design decisions followed, no
  critical or warning issues.
- [ ] 7.2 Archive the change on-branch, before merge, committed as part of the PR (AGENTS.md §2 /
  workflows Phase 4).
