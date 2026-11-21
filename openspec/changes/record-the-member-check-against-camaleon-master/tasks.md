# Tasks

## 1. Documents

- [x] 1.1 Add the four requirements of the member check to the delta spec of this change. Verify:
  each requirement has one or more scenarios
- [x] 1.2 Extend the requirement "Enrollment is documented with the ecosystem inventory" in the
  delta spec. Verify: its two scenarios stay as they are, and a third covers the member check

## 2. Verification and shipping

- [x] 2.1 Run `openspec validate --all --strict`. Verify: the change is valid
- [ ] 2.2 Add the `CHANGELOG.md` entry with the link of the PR. Name the member check in the
  Purpose of the main spec. Archive this change on the branch. Verify:
  `openspec validate --archived` passes
