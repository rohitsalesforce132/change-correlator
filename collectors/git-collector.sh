#!/bin/bash
# Git Change Collector
# Extracts commits from a git repository within a time window
# Usage: bash collectors/git-collector.sh --repo /path/to/repo --since "2 hours ago"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGES_DIR="$PROJECT_DIR/changes"

# Defaults
REPO_PATH=""
SINCE=""
UNTIL=""
AUTHOR=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) REPO_PATH="$2"; shift ;;
        --since) SINCE="$2"; shift ;;
        --until) UNTIL="$2"; shift ;;
        --author) AUTHOR="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$REPO_PATH" ]; then
    echo "Usage: bash git-collector.sh --repo <path> [--since <time>] [--until <time>] [--author <name>]"
    exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
    echo "❌ Not a git repository: $REPO_PATH"
    exit 1
fi

# Build date range
SINCE_ARG=""
UNTIL_ARG=""
[ -n "$SINCE" ] && SINCE_ARG="--since=\"$SINCE\""
[ -n "$UNTIL" ] && UNTIL_ARG="--until=\"$UNTIL\""
[ -n "$AUTHOR" ] && AUTHOR_ARG="--author=\"$AUTHOR\""

echo "🔍 Collecting git commits from: $REPO_PATH"
[ -n "$SINCE" ] && echo "   Since: $SINCE"
[ -n "$UNTIL" ] && echo "   Until: $UNTIL"
echo ""

# Extract commits
cd "$REPO_PATH"

COMMITS=$(eval git log --format='%H|%ai|%an|%s' $SINCE_ARG $UNTIL_ARG $AUTHOR_ARG 2>/dev/null || true)

if [ -z "$COMMITS" ]; then
    echo "No commits found in the specified range."
    exit 0
fi

COUNT=0

while IFS='|' read -r hash date author message; do
    [ -z "$hash" ] && continue
    
    # Parse date
    change_date=$(echo "$date" | awk '{print $1}')
    change_time=$(echo "$date" | awk '{print $2}')
    change_date_clean=$(echo "$change_date" | tr -d '-')
    change_time_clean=$(echo "$change_time" | tr -d ':' | cut -c1-4)
    
    change_id="CHG-GIT-${change_date_clean}-${change_time_clean}"
    change_dir="$CHANGES_DIR/$change_date"
    mkdir -p "$change_dir"
    
    change_file="$change_dir/${change_id}.md"
    
    # Get file list
    files_changed=$(git diff-tree --no-commit-id --name-only -r "$hash" 2>/dev/null | head -20 || echo "Unknown")
    
    # Get stats
    stats=$(git show --stat --format="" "$hash" 2>/dev/null | tail -1 || echo "Unknown")
    
    # Determine severity
    severity="normal"
    if echo "$message" | grep -qi "hotfix\|urgent\|critical\|rollback"; then
        severity="high"
    elif echo "$message" | grep -qi "breaking\|major\|migration"; then
        severity="medium"
    fi
    
    cat > "$change_file" <<EOF
---
id: $change_id
timestamp: $date
source: git
severity: $severity
author: $author
commit: $hash
tags: [git, commit]
related_incidents: []
---

# Git Commit: ${hash:0:7}

**Type:** Code Change
**Author:** $author
**Date:** $date
**Message:** $message

## What Changed
$message

## Files Changed
\`\`\`
$files_changed
\`\`\`

## Stats
$stats
EOF
    
    echo "  ✅ $change_id: ${message:0:60}..."
    COUNT=$((COUNT + 1))
    
done <<< "$COMMITS"

echo ""
echo "📊 Collected $COUNT git commits."
