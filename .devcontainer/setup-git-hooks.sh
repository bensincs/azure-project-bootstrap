#!/bin/bash
# Git hooks setup script
# This script sets up Git hooks from the .devcontainer/.hooks directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SOURCE_DIR="$SCRIPT_DIR/.hooks"
GIT_HOOKS_DIR="/workspace/.git/hooks"

echo "🔧 Setting up Git hooks..."

# Check if we're in a Git repository
if [ ! -d "/workspace/.git" ]; then
    echo "❌ Not in a Git repository. Git hooks setup skipped."
    exit 0
fi

# Check if hooks source directory exists
if [ ! -d "$HOOKS_SOURCE_DIR" ]; then
    echo "❌ Hooks source directory not found: $HOOKS_SOURCE_DIR"
    exit 1
fi

# Create git hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Copy hooks from source directory to git hooks directory
for hook_file in "$HOOKS_SOURCE_DIR"/*; do
    if [ -f "$hook_file" ]; then
        hook_name=$(basename "$hook_file")
        target_file="$GIT_HOOKS_DIR/$hook_name"

        echo "📋 Installing $hook_name hook..."
        cp "$hook_file" "$target_file"
        chmod +x "$target_file"

        echo "✅ $hook_name hook installed and made executable"
    fi
done

echo ""
echo "🎉 Git hooks setup completed!"
echo "📁 Hooks installed in: $GIT_HOOKS_DIR"
echo ""
echo "📚 Available hooks:"
ls -la "$GIT_HOOKS_DIR" | grep -v "^d" | awk '{print "  - " $9}' | grep -v "^  - $"
echo ""
echo "💡 These hooks will automatically run during Git operations:"
echo "  - pre-commit: Runs linting on staged Python files"
echo "  - pre-push: Runs comprehensive checks before pushing"