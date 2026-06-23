#!/usr/bin/env bash
# pr-review-start.sh
#
# Stage a feature branch as a working-tree diff against its merge-base so the
# whole PR appears as local changes in VS Code Source Control.
#
# Usage:
#   pr-review-start.sh <feature_ref> [base_ref]
#
# Pass fully-qualified refs. Branch names may themselves contain '/'
# (e.g. 'vabhork/load_issue'), so always prefix with the remote:
#
# Examples:
#   pr-review-start.sh origin/my-feature
#   pr-review-start.sh origin/vabhork/load_issue
#   pr-review-start.sh origin/vabhork/load_issue origin/Release/EN_ENM3
#
# Defaults:
#   base_ref = origin/main
#
# Pair with: pr-review-end.sh

set -euo pipefail

REVIEW_BRANCH="ai-pr-review"
# STATE_FILE is set after we resolve the repo root so 'git rev-parse --git-path'
# returns the correct internal path (handles linked worktrees and submodules
# where '.git' is a file, not a directory).
STATE_FILE=""

err() { echo "error: $*" >&2; exit 1; }
info() { echo "[pr-review] $*"; }

# --- args ---
if [[ $# -lt 1 || $# -gt 2 ]]; then
    err "usage: $(basename "$0") <feature_ref> [base_ref]"
fi
feature_ref="$1"
base_ref="${2:-origin/main}"

# --- must be in a git repo ---
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || err "not inside a git working tree"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

STATE_FILE="$(git rev-parse --git-path PR_REVIEW_PREV_BRANCH)"

# --- clean tree check ---
if [[ -n "$(git status --porcelain)" ]]; then
    err "working tree is not clean. Commit or stash changes first."
fi

# --- review branch must not already exist ---
if git show-ref --verify --quiet "refs/heads/${REVIEW_BRANCH}"; then
    err "branch '${REVIEW_BRANCH}' already exists. Run pr-review-end.sh first."
fi

# --- save current branch (or detached HEAD sha) ---
if current_branch="$(git symbolic-ref --short -q HEAD)"; then
    :
else
    current_branch="$(git rev-parse HEAD)"
fi
info "current ref: $current_branch"

# --- fetch the refs we need ---
# Always fetch 'origin' --prune. Do NOT try to derive a remote from the ref
# name: a branch like 'vabhork/load_issue' contains '/' but is NOT
# '<remote>/<branch>'. Users should pass fully-qualified refs like
# 'origin/vabhork/load_issue' so resolution is unambiguous.
info "fetching from origin ..."
git fetch origin --prune

# --- verify both refs resolve ---
git rev-parse --verify --quiet "$feature_ref" >/dev/null \
    || err "feature ref '$feature_ref' not found. Try prefixing with 'origin/' (e.g. origin/$feature_ref)."
git rev-parse --verify --quiet "$base_ref" >/dev/null \
    || err "base ref '$base_ref' not found"

# --- compute merge-base ---
mb="$(git merge-base "$base_ref" "$feature_ref")" \
    || err "no merge-base between '$base_ref' and '$feature_ref'"
if [[ -z "$mb" ]]; then
    err "merge-base is empty"
fi
info "base:       $base_ref"
info "feature:    $feature_ref"
info "merge-base: $mb"

# --- create review branch pointing at the feature tip ---
git switch -c "$REVIEW_BRANCH" "$feature_ref"

# --- soft reset to merge-base ---
# After this:
#   HEAD            -> merge-base ($mb)
#   working tree    -> still the feature tip (unchanged on disk)
#   index           -> all feature changes are staged
# That is exactly what we want: VS Code will render the full PR diff as
# local edits against the merge-base snapshot.
git reset --soft "$mb"

# --- unstage so VS Code shows under "Changes" instead of "Staged Changes" ---
git reset >/dev/null

# --- persist previous branch for pr-review-end.sh ---
printf '%s\n' "$current_branch" > "$STATE_FILE"

# --- summary ---
changed_files="$(git diff --name-only | wc -l | tr -d ' ')"
info "review branch: $REVIEW_BRANCH"
info "changed files: $changed_files"
info "done. Open VS Code Source Control to review."
info "When finished, run: pr-review-end.sh"
