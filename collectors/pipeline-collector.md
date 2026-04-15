# Pipeline Change Collector

> Extracts CI/CD pipeline runs from Azure DevOps or GitHub Actions.

## Azure DevOps

```bash
# List recent pipeline runs
az pipelines runs list --pipeline-name payment-api --top 50

# Filter by status
az pipelines runs list --pipeline-name payment-api --status completed --top 20

# Get specific run details
az pipelines runs show --id 4521

# Get run timeline (stages/jobs)
az pipelines runs timeline --id 4521
```

### Example Output

```json
{
  "id": 4521,
  "status": "completed",
  "result": "succeeded",
  "sourceBranch": "refs/heads/main",
  "startTime": "2026-04-12T12:23:00Z",
  "finishTime": "2026-04-12T12:28:00Z",
  "requestedBy": { "displayName": "developer-b" }
}
```

## GitHub Actions

```bash
# List recent workflow runs
gh run list --repo owner/repo --limit 50

# Get run details
gh run view <run-id> --repo owner/repo

# Get run logs
gh run view <run-id> --log --repo owner/repo

# List workflow runs for specific workflow
gh run list --repo owner/repo --workflow deploy.yml --limit 20
```

### Example Output

```
ID         STATUS     CONCLUSION  BRANCH  EVENT
4521       completed  success     main    push
4520       completed  failure     dev     push
```

## Building a Change File

For each pipeline run, create a Markdown file in `changes/YYYY-MM-DD/`:

```markdown
---
id: CHG-PIPE-20260412-1223
timestamp: 2026-04-12T12:23:00+05:30
source: pipeline
severity: normal
author: developer-b
pipeline: payment-api
run_id: "4521"
status: completed
result: succeeded
branch: refs/heads/main
tags: [pipeline, deploy, payment-api]
related_incidents: []
---

# Pipeline Run: #4521

**Type:** Pipeline Deployment
**Pipeline:** payment-api
**Status:** completed
**Result:** succeeded
**Branch:** refs/heads/main
**Requested By:** developer-b
**Start:** 2026-04-12T12:23:00Z
**Finish:** 2026-04-12T12:28:00Z

## What Changed
Deployed payment-api:v2.3.1 to production

## Artifacts
- payment-api:v2.3.1 (container image)
- helm chart: payment-api-2.3.1.tgz
```

## Severity Detection

| Pipeline Result | Severity |
|----------------|----------|
| failed | high |
| canceled | medium |
| succeeded with warnings | medium |
| succeeded | normal |

## Quick Commands

```bash
# Azure DevOps: Get all failed runs today
az pipelines runs list --status completed --result failed --top 50

# GitHub Actions: Get all failed runs
gh run list --repo owner/repo --status completed --json conclusion | jq '.[] | select(.conclusion=="failure")'

# Azure DevOps: Get run artifacts
az pipelines runs artifact list --run-id 4521

# GitHub Actions: Re-run a failed workflow
gh run rerun <run-id> --repo owner/repo
```
