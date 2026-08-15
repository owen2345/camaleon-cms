# Releasing

Releases are cut by the **Release** GitHub Actions workflow
([`.github/workflows/release.yml`](../.github/workflows/release.yml)). It only runs when you start
it by hand — merging to `master` releases nothing. A single run does everything a release needs, in
this order:

1. verifies the release is safe to cut (see [What the workflow checks](#what-the-workflow-checks)),
2. builds the gem and inspects the built artifact,
3. pushes it to RubyGems,
4. creates the annotated git tag,
5. publishes the GitHub release, with notes taken from `CHANGELOG.md` and the `.gem` plus its
   checksums attached.

The suite is not re-run here. It already ran against the release commit when that commit landed on
`master`, so the workflow requires those runs to have succeeded rather than spending ~20 minutes
revalidating a tree that has not changed.

`lib/camaleon_cms/version.rb` is the single source of truth for the version. The tag, the published
gem and the GitHub release all derive from it, so they cannot disagree.

> **`2.9.3` below is only an example.** Every command, filename and heading in this document uses it
> as a stand-in for the version you are actually releasing — substitute yours as you go. This
> document is not updated each release, so do not expect the number here to be the next one.

## Before you start

- You need **write access** to this repository.
- The `RUBY_GEMS_PUBLISH_GEM_KEY` repository secret must exist — it is the RubyGems API key the
  workflow publishes with. It is already configured; you never need to see or handle its value.
- You do **not** need RubyGems credentials on your own machine for the automated release. You only
  need them for the [manual fallback](#fallback-releasing-entirely-by-hand).

## Step 1 — Open a release PR

Create a branch, bump the version, and turn the accumulated notes into a released section:

```bash
git checkout master && git pull
git checkout -b release/2.9.3
```

Edit `lib/camaleon_cms/version.rb`:

```ruby
module CamaleonCms
  VERSION = '2.9.3'.freeze
end
```

Then rename the `## Unreleased` heading at the top of `CHANGELOG.md` to the version you are
shipping. That rename is what makes the workflow pick those notes up — everything between that
heading and the next `## ` becomes the GitHub release body.

Both heading shapes are recognised, so match the style of the sections around it:

```markdown
## [2.9.3](https://github.com/owen2345/camaleon-cms/tree/2.9.3) (2026-08-15)
```

```markdown
## 2.9.3
```

What the workflow reads is the **first word of the heading**, taking the link text when the heading
is a link. A trailing date is ignored. A heading it cannot match to the version you typed —
including a leftover `## Unreleased` — silently costs you your release notes and falls back to a
bare commit list.

Commit, push, open the PR, and merge it once it is approved:

```bash
git commit -am "Release 2.9.3"
```

```bash
git push -u origin release/2.9.3
```

```bash
gh pr create --title "Release 2.9.3" --body "Bumps the version and closes the changelog section."
```

> **Do not skip CI on the release PR.** The workflow refuses to publish a commit that has no
> successful CI runs recorded against it, and a `[skip ci]` marker on the head commit of a push
> produces none. Merging with a **merge commit** — this repository's convention — is safe whatever
> the branch commits say, because the merge commit's own message carries no marker. A squash or
> rebase merge can carry the marker onto `master` and leave the release ungatable; if that happens,
> see [What the workflow checks](#what-the-workflow-checks).

## Step 2 — Wait for CI on `master`

Merging does **not** publish anything, but it does start the checks the release depends on. Wait
for **Test supported versions** and **Audit** to finish green on `master` before going further —
the release stops at its first check otherwise.

## Step 3 — Run the Release workflow

1. Open the repository on GitHub.
2. Click the **Actions** tab (in the top row, next to *Pull requests*).
3. In the left sidebar, under *All workflows*, click **Release**.
4. On the right-hand side of the blue banner, click the **Run workflow** dropdown button.
5. Leave **Use workflow from** as `Branch: master`. The workflow refuses to run from any other
   branch, so a gem can never be published from unmerged code.
6. In **Version to release**, type the version exactly as it appears in `version.rb` — not the
   `2.9.3` of this example. A leading `v` is accepted and stripped, and a mismatch fails the run
   before anything is published.
7. Click the green **Run workflow** button.

The page takes a few seconds to show the new run; reload if it does not appear. Click into the run
to watch the three jobs — *Verify and build*, *Publish to RubyGems*, and *Tag and publish GitHub
release* — go green in turn.

> If the **Release** workflow is not listed in step 3, the workflow file has not reached `master`
> yet. GitHub only offers a manually-triggered workflow once its file exists on the default branch.
> Merge the PR first.

## Step 4 — Confirm

- **RubyGems**: <https://rubygems.org/gems/camaleon_cms/versions/2.9.3> — it can take a minute or
  two to appear.
- **GitHub**: the repository's *Releases* page should show *Release 2.9.3* with your changelog text
  and three attached files (`.gem`, `.sha256`, `.sha512`).
- Locally: `gem fetch camaleon_cms -v 2.9.3`

## What the workflow checks

Every check runs *before* anything is published, because pushing to RubyGems is the only step that
cannot be undone — a version can be yanked, but that version number can never be re-used. If a
check fails, nothing has been published and nothing has been tagged: fix the cause and start the
workflow again.

| Failure message | Cause | Fix |
| --- | --- | --- |
| `is not a valid gem version` | Typo in the input box | Re-run with the correct version |
| `Releases must be cut from master` | *Use workflow from* was not `master` | Re-run from `master` |
| `does not match lib/camaleon_cms/version.rb` | The typed version and `version.rb` disagree | Bump `version.rb`, or type the version it already has |
| `Tag <version> already exists` | That version was released before | Bump to a new version |
| `already published on RubyGems` | Same, but caught on the RubyGems side | Bump to a new version |
| `<workflow> has no successful run for <sha>` | CI for the release commit failed, is still running, or never ran | Wait for it, fix what is red, or — if CI was skipped for that commit — push a further commit without a skip-ci marker and release from that one |
| `No release notes` | No matching section in `CHANGELOG.md` **and** no commits since the last tag | Add the changelog section |
| `gem build` fails under `--strict` | The gemspec has a warning (missing homepage, missing `required_ruby_version`, …) | Fix the gemspec |
| `Test files packaged into the gem` | `s.test_files` was added to the gemspec | Remove it — RubyGems merges `test_files` into `files` |
| `<file> is missing from the gem` | A filename in `s.files` no longer matches a real file | Correct the name in the gemspec |

Only `current_support.yml` (*Test supported versions*) and `audit.yml` (*Audit*) gate the release.
`experimental_support.yml` tests Ruby head and Rails edge, which are expected to break for reasons
that have nothing to do with a release, so it is not required.

The one failure that needs manual recovery is a job that fails *after* `gem push` succeeded — the
gem is public, but the tag and release were never created. Do not re-run the workflow, it would
stop at the "already published" check. Finish it by hand instead, using steps 5 and 6 of the
fallback below.

## Fallback: releasing entirely by hand

Use this if Actions is down, if the workflow is broken, or to finish a release that failed after
the gem was already pushed. It needs your own RubyGems credentials, and you must be an owner of the
gem on RubyGems.

As above, **`2.9.3` is a stand-in for the version you are releasing** — every command below needs
your own number substituted in, including the `.gem` filenames.

Sign in to RubyGems once per machine — this writes a token to `~/.gem/credentials`:

```bash
gem signin
```

Then, from a clean checkout of `master` with the correct version already in `version.rb`:

**1. Start from exactly what you intend to publish.**

```bash
git checkout master && git pull && git status
```

`git status` must report a clean tree — `gem build` packages the files on disk, so any stray local
edit would end up in the published gem.

**2. Build the gem.**

```bash
gem build camaleon_cms.gemspec --strict
```

`--strict` turns gemspec warnings into errors. It needs RubyGems 4 or newer: older versions warn
about this gemspec's open-ended dependencies and refuse to build under `--strict`. Check with
`gem --version`, and update with `gem update --system` if needed.

**3. Inspect what you are about to publish.** This is the step the workflow automates; publishing
is irreversible, so it is worth the minute.

```bash
gem unpack camaleon_cms-2.9.3.gem --target /tmp/gem-check
```

```bash
find /tmp/gem-check -type f | sort
```

Expect about 740 files: `LICENSE`, `README.md` and `Rakefile` at the root, and the rest under
`app/`, `config/`, `db/` and `lib/`. There must be **no `spec/` directory** and no credentials of
any kind.

**4. Push to RubyGems.** If your account has MFA enabled for publishing, this prompts for a
one-time code.

```bash
gem push camaleon_cms-2.9.3.gem
```

**5. Create and push the tag.** Annotated (`-a`), and unprefixed, to match every recent tag in this
repository:

```bash
git tag -a 2.9.3 -m "Release 2.9.3"
```

```bash
git push origin 2.9.3
```

**6. Publish the GitHub release.** Either with the CLI:

```bash
gh release create 2.9.3 --title "Release 2.9.3" --notes-file notes.md camaleon_cms-2.9.3.gem
```

where `notes.md` holds the changelog section for this version — or through the web interface:

1. On the repository's front page, click **Releases** in the right-hand sidebar.
2. Click **Draft a new release**.
3. In **Choose a tag**, select the `2.9.3` tag you pushed in step 5.
4. Set **Target** to `master`.
5. Set the title to `Release 2.9.3`.
6. Paste the `CHANGELOG.md` section for this version into the description box.
7. Drag `camaleon_cms-2.9.3.gem` into the *Attach binaries* area at the bottom.
8. Click **Publish release**.
