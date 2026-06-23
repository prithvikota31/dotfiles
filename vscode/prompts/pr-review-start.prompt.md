---
description: "Stage a feature branch as working-tree edits against its merge-base so the entire PR shows as local changes in VS Code Source Control, ready for AI/Copilot review. Use when the user says 'review PR', 'review feature branch', 'load PR for review', or asks to preview a branch as local changes."
name: "PR Review: Start"
argument-hint: "<feature_ref> [base_ref]"
agent: "agent"
---

# PR Review — Start

Run the personal helper script `~/bin/pr-review-start.sh` to stage a feature branch for review as local working-tree changes.

## Inputs

The user provides:
- `feature_ref` (required): MUST be a fully-qualified ref such as `origin/<branch>` or a commit SHA. Plain branch names are ambiguous because branch names may contain `/` (e.g. `vabhork/load_issue` is a branch, not `<remote>/<branch>`). If the user gives a bare name, ask them to re-issue with `origin/` prefix.
- `base_ref` (optional, defaults to `origin/main`): the branch the PR will merge into.

If `feature_ref` is missing, ask the user for it before running anything. Do not guess.

## Pre-flight

Before running the script:
1. Confirm the current working directory is inside the repo the user wants to review in (`git rev-parse --show-toplevel`). If unsure, ask.
2. Confirm `git status --porcelain` is empty. If not, stop and tell the user to commit or stash first — do NOT run the script on a dirty tree.
3. Confirm a branch named `ai-pr-review` does not already exist. If it does, tell the user to run `/pr-review-end` first.

## Run

Invoke the script with the supplied args:

```bash
~/bin/pr-review-start.sh <feature_ref> [base_ref]
```

The script will:
- Save the current branch to `$(git rev-parse --git-path PR_REVIEW_PREV_BRANCH)` (worktree/submodule safe).
- Fetch from `origin --prune`.
- Compute the merge-base.
- Create `ai-pr-review` at the feature tip.
- `git reset --soft` to the merge-base, then `git reset` to unstage.
- Print a summary (base, feature, merge-base SHA, changed file count).

## After

- Report the merge-base SHA and the changed-file count back to the user.
- Tell the user: "VS Code Source Control now shows all PR changes as local edits. Run `/pr-review-end` when done."
- Do NOT auto-start a code review. Wait for the user to ask.

## Failure handling

If the script exits non-zero, do not retry blindly. Show the exact error and:
- "working tree is not clean" → ask user to stash/commit.
- "branch 'ai-pr-review' already exists" → suggest `/pr-review-end`.
- "no merge-base" → ask the user to verify base/feature refs.
- "ref not found" → most likely the user passed a bare branch name; ask them to retry with `origin/<branch>`.
