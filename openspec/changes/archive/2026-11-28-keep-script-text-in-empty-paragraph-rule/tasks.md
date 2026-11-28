# Tasks

## 1. Fix the rule

- [x] 1.1 Add `spec/features/admin/post_editor_empty_paragraph_spec.rb`. Verify: the script and
  comment examples fail with the old rule
- [x] 1.2 Replace the `PostProcess` regular expression with the mark of `design.md` D1. Verify: the
  spec passes
- [x] 1.3 Compare the old and the new output outside the text of scripts, comments and the other
  markup that `proposal.md` names. Verify: the output is the same for `getContent` and for the content of
  a selection
- [x] 1.4 Add the `text-editor-empty-paragraphs` spec. Verify: `openspec validate --all --strict`
  passes

## 2. Archive

- [x] 2.1 Archive the change on the branch, with the sync of the delta spec. Verify:
  `openspec validate --archived` passes
