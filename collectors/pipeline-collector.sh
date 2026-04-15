#!/bin/bash
# Pipeline Change Collector
# Extracts CI/CD pipeline runs within a time window
# Usage: bash collectors/pipeline-collector.sh --pipeline payment-api --since "2 hours ago"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGES_DIR="$PROJECT_DIR/changes"

PIPELINE=""
SINCE=""
UNTIL=""
STATUS=""
LIMIT=50

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --pipeline) PIPELINE="$2"; shift ;;
        --since) SINCE="$2"; shift ;;
        --until) UNTIL="$2"; shift ;;
        --status) STATUS="$2"; shift ;;
        --limit) LIMIT="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$PIPELINE" ]; then
    echo "Usage: bash pipeline-collector.sh --pipeline <name> [--since <time>] [--until <time>] [--status <status>]"
    echo ""
    echo "Supports: Azure DevOps pipelines, GitHub Actions"
    echo ""
    echo "Examples:"
    echo "  # Azure DevOps"
    echo "  bash pipeline-collector.sh --pipeline payment-api --since '2 hours ago'"
    echo ""
    echo "  # GitHub Actions"
    echo "  bash pipeline-collector.sh --pipeline ci --since '24 hours ago'"
    exit 1
fi

echo "🔍 Collecting pipeline runs for: $PIPELINE"
echo ""

COUNT=0

# Try Azure DevOps first
if command -v az &>/dev/null; then
    echo "   Trying Azure DevOps..."
    
    # Build query
    QUERY="--pipeline-name $PIPELINE"
    [ -n "$STATUS" ] && QUERY="$QUERY --status $STATUS"
    [ -n "$LIMIT" ] && QUERY="$QUERY --top $LIMIT"
    
    RUNS=$(az pipelines runs list $QUERY 2>/dev/null || true)
    
    if [ -n "$RUNS" ] && [ "$RUNS" != "[]" ]; then
        echo "$RUNS" | jq -c '.[]' 2>/dev/null | while read -r run; do
            run_id=$(echo "$run" | jq -r '.id // "unknown"')
            run_status=$(echo "$run" | jq -r '.status // "unknown"')
            run_result=$(echo "$run" | jq -r '.result // "unknown"')
            run_source_branch=$(echo "$run" | jq -r '.sourceBranch // "unknown"')
            run_start=$(echo "$run" | jq -r '.startTime // "unknown"')
            run_finish=$(echo "$run" | jq -r '.finishTime // "unknown"')
            run_requested_by=$(echo "$run" | jq -r '.requestedBy.displayName // "unknown"')
            
            # Parse date
            change_date=$(echo "$run_start" | cut -dT -f1 | tr -d '-')
            change_time=$(echo "$run_start" | cut -dT -f2 | tr -d ':' | cut -c1-4)
            
            change_id="CHG-PIPE-${change_date}-${change_time}"
            change_dir="$CHANGES_DIR/$(echo "$run_start" | cut -dT -f1)"
            mkdir -p "$change_dir"
            
            severity="normal"
            [ "$run_result" = "failed" ] && severity="high"
            [ "$run_result" = "canceled" ] && severity="medium"
            
            cat > "$change_dir/${change_id}.md" <<EOF
---
id: $change_id
timestamp: $run_start
source: pipeline
severity: $severity
author: $run_requested_by
pipeline: $PIPELINE
run_id: $run_id
status: $run_status
result: $run_result
branch: $run_source_branch
tags: [pipeline, deploy, $PIPELINE]
related_incidents: []
---

# Pipeline Run: #$run_id

**Type:** Pipeline Deployment
**Pipeline:** $PIPELINE
**Status:** $run_status
**Result:** $run_result
**Branch:** $run_source_branch
**Requested By:** $run_requested_by
**Start:** $run_start
**Finish:** $run_finish

## What Changed
Pipeline $PIPELINE run #$run_id — $run_result

## Artifacts
[Populate from pipeline output]
EOF
            
            echo "  ✅ $change_id: #$run_id ($run_result)"
            COUNT=$((COUNT + 1))
        done
    fi
fi

# Try GitHub Actions
if [ -n "$GITHUB_REPOSITORY" ] || git remote get-url origin 2>/dev/null | grep -q github; then
    echo "   Trying GitHub Actions..."
    
    REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "")
    
    if [ -n "$REPO" ] && command -v gh &>/dev/null; then
        gh run list --repo "$REPO" --limit "$LIMIT" --json databaseId,status,conclusion,headBranch,createdAt,event 2>/dev/null | \
        jq -c '.[]' 2>/dev/null | while read -r run; do
            run_id=$(echo "$run" | jq -r '.databaseId // "unknown"')
            run_status=$(echo "$run" | jq -r '.status // "unknown"')
            run_conclusion=$(echo "$run" | jq -r '.conclusion // "unknown"')
            run_branch=$(echo "$run" | jq -r '.headBranch // "unknown"')
            run_created=$(echo "$run" | jq -r '.createdAt // "unknown"')
            run_event=$(echo "$run" | jq -r '.event // "unknown"')
            
            change_date=$(echo "$run_created" | cut -dT -f1 | tr -d '-')
            change_time=$(echo "$run_created" | cut -dT -f2 | tr -d ':' | cut -c1-4)
            
            change_id="CHG-GHA-${change_date}-${change_time}"
            change_dir="$CHANGES_DIR/$(echo "$run_created" | cut -dT -f1)"
            mkdir -p "$change_dir"
            
            severity="normal"
            [ "$run_conclusion" = "failure" ] && severity="high"
            
            cat > "$change_dir/${change_id}.md" <<EOF
---
id: $change_id
timestamp: $run_created
source: github-actions
severity: $severity
pipeline: $PIPELINE
run_id: $run_id
status: $run_status
conclusion: $run_conclusion
branch: $run_branch
event: $run_event
tags: [pipeline, github-actions, $PIPELINE]
related_incidents: []
---

# GitHub Actions Run: #$run_id

**Type:** CI/CD Pipeline
**Workflow:** $PIPELINE
**Status:** $run_status
**Conclusion:** $run_conclusion
**Branch:** $run_branch
**Event:** $run_event
**Created:** $run_created

## What Changed
GitHub Actions workflow run #$run_id — $run_conclusion
EOF
            
            echo "  ✅ $change_id: #$run_id ($run_conclusion)"
        done
    fi
fi

if [ "$COUNT" -eq 0 ]; then
    echo "   No pipeline runs found."
    echo "   Ensure 'az' (Azure DevOps) or 'gh' (GitHub Actions) CLI is configured."
fi

echo ""
echo "📊 Collected $COUNT pipeline runs."
