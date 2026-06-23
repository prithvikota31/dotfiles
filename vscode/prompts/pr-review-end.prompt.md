---
description: "Tear down the ai-pr-review branch created by /pr-review-start: hard-reset the working tree, switch back to the previously-active branch, and delete ai-pr-review. Use when the user says 'end PR review', 'finish PR review', 'cleanup PR review', or 'done reviewing'."
name: "PR Review: End"
agent: "agent"
---

# PR Review — End

Run the personal helper script `~/bin/pr-review-end.sh` to tear down the state created by `/pr-review-start`.

## Pre-flight

Before running:
1. Confirm the current branch is `ai-pr-review`:
   ```bash
   git symbolic-ref --short -q HEAD
   ```
   If not, stop and tell the user — running the script outside `ai-pr-review` will error out anyway.
2. Confirm the state file exists at `$(git rev-parse --git-path PR_REVIEW_PREV_BRANCH)`. If missing, tell the user the state file is gone and ask which branch they want to return to (then they can `git switch` manually).

## Run

```bash
~/bin/pr-review-end.sh
```

The script will:
- `git reset --hard` (discards working-tree edits — this is expected; the edits are the PR diff).
- Read the saved previous branch and `git switch` to it.
- Delete the `ai-pr-review` branch.
- Remove the state file.

## After

Confirm to the user:
- Which branch they were returned to.
- That `ai-pr-review` was deleted.

## Failure handling

- "not on 'ai-pr-review'" → tell the user the workflow was already cleaned up or never started.
- "state file missing" → ask the user which branch to switch back to.
