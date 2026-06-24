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
# 1. Detects the root of the git repo you're currently inside.
# 2. Creates `<repo>/.github/prompts/` if missing.
# 3. Symlinks the two prompt files there, pointing back at this dotfiles repo:
#       <repo>/.github/prompts/pr-review-start.prompt.md  -> ~/dotfiles/...
#       <repo>/.github/prompts/pr-review-end.prompt.md    -> ~/dotfiles/...
# 4. Adds those two paths to `.git/info/exclude` so they never show up as
#    untracked files in `git status` (local-only, never committed).
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
# Step 1 (per repo — run this script from inside the target repo):
#
#   cd /path/to/your/repo
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

# --- sanity: must be inside a git repo ---
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || err "not inside a git repository. cd into a repo first, then re-run."

info "target repo: $repo_root"

# --- ensure .github/prompts/ exists ---
prompts_dir="$repo_root/.github/prompts"
mkdir -p "$prompts_dir"

# --- ensure .git/info/exclude exists (rare cases it doesn't) ---
exclude_file="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$exclude_file")"
touch "$exclude_file"

# --- symlink each prompt + mark as locally-ignored ---
for f in "${PROMPTS[@]}"; do
    src="$DOTFILES/vscode/prompts/$f"
    dst="$prompts_dir/$f"
    rel=".github/prompts/$f"

    [[ -f "$src" ]] || err "missing source file: $src"

    ln -sfn "$src" "$dst"
    info "linked: $rel -> $src"

    # Add to .git/info/exclude (local-only ignore, never committed)
    if ! grep -qxF "$rel" "$exclude_file"; then
        echo "$rel" >> "$exclude_file"
        info "ignored locally: $rel"
    fi
done

echo
info "done. Reload VS Code window (Ctrl+Shift+P -> 'Developer: Reload Window')."
info "Then type '/' in Copilot Chat to see /pr-review-start and /pr-review-end."
