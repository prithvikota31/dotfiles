#!/usr/bin/env bash
#
# install-prompts-here.sh
#
# Installs the Copilot prompts (/pr-review-start, /pr-review-end) into the
# current git repository so they appear as slash commands in VS Code Chat.
#
# ----------------------------------------------------------------------------
# WHAT THIS SCRIPT DOES
# ----------------------------------------------------------------------------
# 1. Verifies you're inside a git repo (for safety) but installs at the
#    CURRENT DIRECTORY (`$PWD`), not the git top-level. This matters for
#    repos where the VS Code workspace is a subdirectory of the git root
#    (e.g. workspace = `repo/src/`, git root = `repo/`). VS Code only scans
#    `<workspace>/.github/prompts/`, so the prompts must live there.
# 2. Creates `$PWD/.github/prompts/` if missing.
# 3. Symlinks the two prompt files there, pointing back at this dotfiles repo:
#       $PWD/.github/prompts/pr-review-start.prompt.md  -> ~/dotfiles/...
#       $PWD/.github/prompts/pr-review-end.prompt.md    -> ~/dotfiles/...
# 4. Adds those two paths to `.git/info/exclude` (relative to git root) so
#    they never show up as untracked files in `git status` (local-only,
#    never committed).
#
# Idempotent: safe to run multiple times. `ln -sfn` overwrites stale symlinks,
# and the exclude entries are deduplicated.
#
# ----------------------------------------------------------------------------
# HOW TO RUN
# ----------------------------------------------------------------------------
# Step 0 (one-time per machine — do this BEFORE running this script):
#
#   # Clone the dotfiles repo
#   git clone https://github.com/prithvikota31/dotfiles.git ~/dotfiles
#
#   # Symlink the bash scripts into ~/bin so they're on $PATH
#   mkdir -p ~/bin
#   ln -sfn ~/dotfiles/bin/pr-review-start.sh ~/bin/pr-review-start.sh
#   ln -sfn ~/dotfiles/bin/pr-review-end.sh   ~/bin/pr-review-end.sh
#
#   # Make sure ~/bin is on $PATH (skip if already configured)
#   grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
#   source ~/.bashrc
#
# Step 1 (per repo — run from your VS Code WORKSPACE root, which is what
#         VS Code opens when you launch it; may be a subdirectory of the git
#         repo, e.g. `repo/src/`):
#
#   cd /path/to/your/vscode/workspace/root
#   ~/dotfiles/install-prompts-here.sh
#
# Step 2:
#
#   In VS Code: Ctrl+Shift+P -> "Developer: Reload Window"
#   Then in Copilot Chat, type "/" and you'll see /pr-review-start and
#   /pr-review-end alongside any existing prompts.
#
# ----------------------------------------------------------------------------
# UNINSTALL (per repo)
# ----------------------------------------------------------------------------
#   cd /path/to/your/repo
#   rm .github/prompts/pr-review-start.prompt.md
#   rm .github/prompts/pr-review-end.prompt.md
#   # The .git/info/exclude entries can stay; they're harmless.
#
# ----------------------------------------------------------------------------

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
PROMPTS=(
    "pr-review-start.prompt.md"
    "pr-review-end.prompt.md"
)

err()  { echo "error: $*" >&2; exit 1; }
info() { echo "[install-prompts] $*"; }

# --- sanity: dotfiles repo must exist ---
[[ -d "$DOTFILES/vscode/prompts" ]] \
    || err "dotfiles not found at '$DOTFILES'. Clone it first: git clone https://github.com/prithvikota31/dotfiles.git ~/dotfiles"

# --- sanity: must be inside a git repo (so we can write .git/info/exclude) ---
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || err "not inside a git repository. cd into your workspace first, then re-run."

# Target the CURRENT DIRECTORY, not the git top-level. VS Code scans the
# workspace root for .github/prompts/, and the workspace may be a subdirectory
# of the git repo (e.g. Storage-xDPU-xStore/src/ inside Storage-xDPU-xStore/).
workspace="$PWD"
info "git repo root: $repo_root"
info "workspace:     $workspace"

if [[ "$workspace" != "$repo_root" ]]; then
    info "note: workspace differs from git root — installing at workspace."
fi

# --- ensure .github/prompts/ exists at the workspace ---
prompts_dir="$workspace/.github/prompts"
mkdir -p "$prompts_dir"

# --- ensure .git/info/exclude exists (rare cases it doesn't) ---
exclude_file="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$exclude_file")"
touch "$exclude_file"

# Path to record in .git/info/exclude must be relative to the git repo root
workspace_rel_to_repo="${workspace#"$repo_root"}"
workspace_rel_to_repo="${workspace_rel_to_repo#/}"  # strip leading slash if any

# --- symlink each prompt + mark as locally-ignored ---
for f in "${PROMPTS[@]}"; do
    src="$DOTFILES/vscode/prompts/$f"
    dst="$prompts_dir/$f"
    if [[ -n "$workspace_rel_to_repo" ]]; then
        rel="$workspace_rel_to_repo/.github/prompts/$f"
    else
        rel=".github/prompts/$f"
    fi

    [[ -f "$src" ]] || err "missing source file: $src"

    ln -sfn "$src" "$dst"
    info "linked: $dst -> $src"

    # Add to .git/info/exclude (local-only ignore, never committed)
    if ! grep -qxF "$rel" "$exclude_file"; then
        echo "$rel" >> "$exclude_file"
        info "ignored locally (relative to git root): $rel"
    fi
done

echo
info "done. Reload VS Code window (Ctrl+Shift+P -> 'Developer: Reload Window')."
info "Then type '/' in Copilot Chat to see /pr-review-start and /pr-review-end."
