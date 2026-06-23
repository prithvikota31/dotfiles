#!/usr/bin/env bash
# pr-review-end.sh
#
# Tear down the state created by pr-review-start.sh:
#   - hard reset working tree
#   - switch back to the branch you were on
#   - delete the ai-pr-review branch
#
# Usage:
#   pr-review-end.sh

set -euo pipefail

REVIEW_BRANCH="ai-pr-review"
# Resolved after we know the repo root; see pr-review-start.sh for why.
STATE_FILE=""

err() { echo "error: $*" >&2; exit 1; }
info() { echo "[pr-review] $*"; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || err "not inside a git working tree"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

STATE_FILE="$(git rev-parse --git-path PR_REVIEW_PREV_BRANCH)"

# --- must be on the review branch ---
current_branch="$(git symbolic-ref --short -q HEAD || echo "")"
if [[ "$current_branch" != "$REVIEW_BRANCH" ]]; then
    err "not on '$REVIEW_BRANCH' (currently on '${current_branch:-detached HEAD}')"
fi

# --- read saved previous branch ---
if [[ ! -f "$STATE_FILE" ]]; then
    err "state file '$STATE_FILE' missing. Cannot determine branch to return to."
fi
prev_branch="$(<"$STATE_FILE")"
[[ -n "$prev_branch" ]] || err "saved previous branch is empty"

info "reverting working tree ..."
git reset --hard

info "switching back to: $prev_branch"
# Accept either a branch name or a commit sha.
if git show-ref --verify --quiet "refs/heads/${prev_branch}"; then
    git switch "$prev_branch"
else
    git switch --detach "$prev_branch"
fi

info "deleting branch: $REVIEW_BRANCH"
git branch -D "$REVIEW_BRANCH"

rm -f "$STATE_FILE"
info "done."
