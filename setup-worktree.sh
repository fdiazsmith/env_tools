#!/bin/bash
# Setup a worktree for Docker development
# Usage: ./setup-worktree.sh [worktree-path]
# If no path given, uses current directory (run from within worktree)

set -e

MAIN_REPO="/Users/fdiazsmith/Documents/soffi-main"

# No arg = use current dir, otherwise use arg
if [ -z "$1" ]; then
    WORKTREE="$(pwd)"
else
    WORKTREE="$1"
    # Resolve relative paths
    if [[ "$WORKTREE" != /* ]]; then
        WORKTREE="/Users/fdiazsmith/Documents/$WORKTREE"
    fi
fi

if [ ! -d "$WORKTREE" ]; then
    echo "Error: Directory not found: $WORKTREE"
    exit 1
fi

# Don't run on main repo
if [ "$WORKTREE" = "$MAIN_REPO" ]; then
    echo "Error: Can't run on main repo, only worktrees"
    exit 1
fi

echo "Setting up worktree: $WORKTREE"
echo "Source repo: $MAIN_REPO"
echo ""

# Init submodules FIRST (before copying env files into submodule dirs)
echo "→ Initializing submodules"
cd "$WORKTREE"
git submodule update --init --recursive

# Copy certs (Docker volumes don't follow symlinks)
echo "→ Copying certs/"
rm -rf "$WORKTREE/certs"
cp -r "$MAIN_REPO/certs" "$WORKTREE/certs"

# Copy env files
echo "→ Copying .env"
cp "$MAIN_REPO/.env" "$WORKTREE/.env" 2>/dev/null || echo "  (no .env found)"

echo "→ Copying .env.secrets"
cp "$MAIN_REPO/.env.secrets" "$WORKTREE/.env.secrets" 2>/dev/null || echo "  (no .env.secrets found)"

echo "→ Copying web/.env.local"
cp "$MAIN_REPO/web/.env.local" "$WORKTREE/web/.env.local" 2>/dev/null || echo "  (no web/.env.local found)"

echo "→ Copying codehost/.env.local"
cp "$MAIN_REPO/codehost/.env.local" "$WORKTREE/codehost/.env.local" 2>/dev/null || echo "  (no codehost/.env.local found)"

echo ""
echo "✓ Done! To start Docker in worktree:"
echo "  cd $WORKTREE"
echo "  docker compose -p soffi-main up --build -d"
echo ""
echo "Note: -p soffi-main keeps all containers on same network (for deployments)"
