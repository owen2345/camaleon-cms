# Tasks: admin-jquery3-runtime-surface

Spec-only change: the implementation already ships on `feature/jquery-3-upgrade`. The work is
verifying the written contract against the shipped behavior, then archiving.

## 1. Verify the spec against the shipped implementation

- [x] 1.1 Confirm admin/theme manifests require `jquery3` and the gemspec floors
      `jquery-rails >= 4.6.1` (verify: grep the manifests and `camaleon_cms.gemspec`).
- [x] 1.2 Confirm the SortableJS shim provides `$.fn.sortable` and `$.fn.disableSelection` with
      the surveyed-consumer semantics and that no other jQuery UI widget is provided (verify:
      read the shim asset; existing feature specs for reordering pass).
- [x] 1.3 Confirm the autocomplete adapters honor the `{term:}`/`minLength`/`select` contract and
      that typing never mutates the committed tags field (verify: existing feature specs
      "does not leak uncommitted tag text..." and the adapter-contract specs pass).

## 2. Archive

- [x] 2.1 `openspec archive admin-jquery3-runtime-surface` on the branch; commit the synced
      `openspec/specs/admin-jquery-runtime/spec.md` plus the archived change as part of PR #1274
      (verify: `openspec validate` clean, archived directory present).
