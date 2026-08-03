# Tasks: scoped-upload-roots-and-scan-narrowing

## 1. Red specs

- [x] 1.1 Path roots: caller `allowed_roots:` accepted; extension does not leak to other calls;
  private root legal only in private mode; defaults still reject `/etc/passwd` and traversal
- [x] 1.2 Request-boundary spec: an `allowed_roots` request parameter does not widen validation
  for `crop`/`upload`
- [x] 1.3 Scan narrowings: already-public source not re-scanned; private/remote sources still
  scanned; `Sample data : 42` accepted while `jav<TAB>ascript:`/`java<LF>script:` still rejected
- [x] 1.4 SVG: animated `<animate>`/`<set>` accepted; `<animate onbegin>` and `<foreignObject>`
  still rejected

## 2. Implementation

- [x] 2.1 `cama_canonical_upload_path(path, extra_roots: [])` plus private-mode root; thread
  `allowed_roots:` from `upload_file`/`cama_tmp_upload`
- [x] 2.2 Skip the staging re-scan when the canonicalized source is under `Rails.public_path`
- [x] 2.3 `BLOCKED_SCHEME_PATTERN` tolerates `[\t\n\r]` only
- [x] 2.4 Drop `animate`/`set` from `SvgContentChecker::BANNED_TAGS`

## 3. Verification and close-out

- [x] 3.1 Red→green; full gates (`bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`)
- [x] 3.2 PR + changelog entry (scoped roots, narrowings, and the deferred HTML question)
- [x] 3.3 Archive this change on the branch as part of the PR
