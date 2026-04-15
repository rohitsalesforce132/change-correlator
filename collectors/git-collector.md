# Git Change Collector

> Extracts commits from a git repository within a time window.

## Usage

```bash
# Collect git commits from last 24 hours
git -C /path/to/repo log --format='%H|%ai|%an|%s' --since="24 hours ago"

# Collect from specific branch
git -C /path/to/repo log --format='%H|%ai|%an|%s' --since="2 hours ago" main

# Collect by specific author
git -C /path/to/repo log --format='%H|%ai|%an|%s' --since="24 hours ago" --author="developer-b"

# Collect between two dates
git -C /path/to/repo log --format='%H|%ai|%an|%s' --since="2026-04-12 12:00" --until="2026-04-12 14:30"
```

## Output Format

Each commit maps to a change record:

```
<full-hash>|<iso-date>|<author>|<subject>
```

### Example

```
abc1234567890def|2026-04-12 12:15:00 +0530|developer-b|Update payment-api to v2.3.1
```

## Building a Change File

For each commit, create a Markdown file in `changes/YYYY-MM-DD/`:

```markdown
---
id: CHG-GIT-20260412-1215
timestamp: 2026-04-12T12:15:00+05:30
source: git
severity: normal
author: developer-b
commit: abc1234
tags: [git, commit]
related_incidents: []
---

# Git Commit: abc1234

**Type:** Code Change
**Author:** developer-b
**Message:** Update payment-api to v2.3.1

## What Changed
- Updated payment-api from v2.3.0 to v2.3.1

## Files Changed
git diff-tree --no-commit-id --name-only -r abc1234

## Stats
git show --stat --format="" abc1234
```

## Severity Detection

| Keyword in commit message | Severity |
|--------------------------|----------|
| hotfix, urgent, critical, rollback | high |
| breaking, major, migration | medium |
| everything else | normal |

## Quick Commands

```bash
# Get files changed in a commit
git diff-tree --no-commit-id --name-only -r <hash>

# Get commit stats
git show --stat --format="" <hash>

# Get full diff
git show <hash>

# Check if commit is deployed (look for tag)
git tag --contains <hash>
```
