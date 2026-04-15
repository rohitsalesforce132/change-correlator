# Change Correlator

> **"What changed?"** — The first question after every incident. Now answered in seconds.

**Unified change timeline across Git, Terraform, Kubernetes, Azure, and more.**

---

## The Problem

80% of incidents are caused by changes. But when something breaks, you check:

1. Git commits — "Was there a deploy?"
2. Terraform applies — "Did infra change?"
3. Helm releases — "Did someone upgrade a chart?"
4. ConfigMaps — "Did config change?"
5. Certificates — "Did a cert rotate?"
6. DNS — "Did records change?"
7. Azure Policy — "Did a policy update?"

7 systems. 7 tabs. 7 different time formats. Zero correlation.

**You're guessing which change caused the incident.**

---

## The Solution

**Change Correlator** — Every change across every system, on one timeline.

```
┌─────────────────────────────────────────────────────────────────────┐
│  CHANGE CORRELATOR — Timeline View                                  │
│  Window: 2026-04-12 12:00 — 14:30 IST                              │
│                                                                     │
│  12:15  [GIT]     abc1234  Update payment-api to v2.3.1             │
│  12:23  [PIPE]    #4521    Deploy payment-api:v2.3.1 → production  │
│  12:45  [HELM]    ingress  nginx-ingress upgraded to 4.8.0         │
│  13:00  [CERT]    wildcard *.prod.example.com rotated               │
│  13:15  [TF]      apply    Updated node_pool autoscaling min=3→5   │
│  13:30  [K8S]     config   payment-api-config updated (timeout 30→60) │
│  14:08  [AZ]      policy   New alerting rule added                  │
│  14:23  ⚠️ ALERT  3 nodes NotReady — INCIDENT START                 │
│                                                                     │
│  🔍 CORRELATION: 3 changes in 2h window before incident             │
│     → Git deploy (payment-api) — 2h before                         │
│     → Helm upgrade (nginx-ingress) — 1.5h before                   │
│     → ConfigMap change (payment-api-config) — 53min before         │
│                                                                     │
│  🎯 LIKELY CAUSE: ConfigMap timeout change (53min before alert)     │
│     → payment-api-config timeout changed 30→60s                    │
│     → This affects kubelet health checks                           │
│                                                                     │
│  [View Diff]  [View Timeline Detail]  [Export for Post-Mortem]      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## How It Works

### 1. Change Sources

Each source is a plugin that extracts changes:

| Source | Plugin | What It Captures |
|--------|--------|-----------------|
| Git | `git-collector.sh` | Commits, merges, tags |
| CI/CD | `pipeline-collector.sh` | Deploy runs, artifacts, rollbacks |
| Terraform | `terraform-collector.sh` | Plan/apply output, state changes |
| Kubernetes | `k8s-collector.sh` | Deployments, ConfigMaps, Secrets, events |
| Helm | `helm-collector.sh` | Release upgrades, rollbacks |
| Certificates | `cert-collector.sh` | Rotations, expirations |
| Azure | `azure-collector.sh` | Policy changes, resource modifications |
| DNS | `dns-collector.sh` | Record changes, TTL updates |

### 2. Change Model

Every change is stored as a Markdown file with a standard schema:

```markdown
---
id: CHG-20260412-1215
timestamp: 2026-04-12T12:15:00+05:30
source: git
severity: normal
author: developer-b
tags: [payment-api, deploy, v2.3.1]
related_incidents: []
---

# Git Commit: abc1234

**Type:** Code Change
**Author:** developer-b
**Message:** Update payment-api to v2.3.1

## What Changed
- Updated payment-api from v2.3.0 to v2.3.1
- Changed timeout configuration

## Files Changed
- src/payment/*.java
- pom.xml
```

### 3. Correlation Engine

The correlation engine takes an incident timestamp and finds all changes in a configurable window:

- **Default window:** 2 hours before incident
- **Scoring:** Changes scored by proximity, type, and affected systems
- **Grouping:** Related changes grouped (e.g., commit → pipeline → deploy)

### 4. Timeline Visualization

- Unified chronological view of all changes
- Color-coded by source
- Filterable by type, author, system
- Exportable for post-mortems

---

## Project Structure

```
change-correlator/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── BLOG.md
├── collectors/                    # Change source plugins
│   ├── git-collector.sh           # Extract git commits
│   ├── pipeline-collector.sh      # Extract CI/CD runs
│   ├── terraform-collector.sh     # Extract TF changes
│   ├── k8s-collector.sh           # Extract k8s changes
│   ├── helm-collector.sh          # Extract Helm releases
│   ├── cert-collector.sh          # Extract cert changes
│   └── azure-collector.sh         # Extract Azure changes
├── engine/                        # Correlation engine
│   ├── correlate.sh               # Main correlation logic
│   ├── score.sh                   # Score changes by relevance
│   └── group.sh                   # Group related changes
├── timeline/                      # Timeline generation
│   ├── generate-timeline.sh       # Generate unified timeline
│   └── export-timeline.sh         # Export for post-mortems
├── changes/                       # Stored changes (Markdown)
│   └── 2026-04-12/
│       ├── CHG-20260412-1215.md   # Git commit
│       ├── CHG-20260412-1223.md   # Pipeline deploy
│       └── CHG-20260412-1245.md   # Helm upgrade
├── templates/                     # Change templates
│   ├── git-change.md
│   ├── pipeline-change.md
│   ├── terraform-change.md
│   └── k8s-change.md
├── samples/                       # Sample correlation data
│   └── INC-001-correlation/
│       ├── timeline.md            # Correlated timeline
│       ├── changes.md             # All changes in window
│       ├── correlation.md         # Correlation analysis
│       └── likely-cause.md        # Most likely cause
└── config/
    └── sources.yaml               # Source configuration
```

---

## Usage

### Collect Changes

```bash
# Collect git commits from last 24 hours
./collectors/git-collector.sh --repo /path/to/repo --since "24 hours ago"

# Collect pipeline runs
./collectors/pipeline-collector.sh --pipeline payment-api --since "24 hours ago"

# Collect k8s events
./collectors/k8s-collector.sh --cluster prod-cluster --since "24 hours ago"

# Collect all configured sources
./collectors/collect-all.sh --since "24 hours ago"
```

### Correlate with Incident

```bash
# Find changes in 2h window before incident
./engine/correlate.sh --incident-time "2026-04-12 14:23" --window "2h"

# With specific sources
./engine/correlate.sh --incident-time "2026-04-12 14:23" --window "4h" --sources git,pipeline,k8s
```

### Generate Timeline

```bash
# Visual timeline
./timeline/generate-timeline.sh --incident-time "2026-04-12 14:23" --window "2h"

# Export for post-mortem
./timeline/export-timeline.sh --incident-time "2026-04-12 14:23" --format markdown
```

---

## Sample Correlation (INC-001)

### Changes Detected (2h window before 14:23)

| Time | Source | Change | Risk Score |
|------|--------|--------|-----------|
| 12:15 | GIT | abc1234: payment-api v2.3.1 | 3/10 |
| 12:23 | PIPE | #4521: Deploy payment-api → prod | 4/10 |
| 12:45 | HELM | nginx-ingress 4.7.2 → 4.8.0 | 6/10 |
| 13:00 | CERT | *.prod.example.com rotated | 2/10 |
| 13:15 | TF | node_pool autoscaling min=3→5 | 5/10 |
| 13:30 | K8S | payment-api-config timeout 30→60s | 8/10 ⚠️ |
| 14:08 | AZ | New alerting rule added | 1/10 |

### Correlation Analysis

**Highest Risk Changes:**
1. **K8S ConfigMap change (13:30)** — 53 min before incident
   - timeout changed from 30s to 60s
   - Affects kubelet health check probes
   - ⚠️ Config change to running workload without rollout

2. **Helm upgrade (12:45)** — 1h 38min before incident
   - nginx-ingress controller upgraded
   - Could affect routing and health checks
   - ⚠️ Infra-level change during business hours

3. **Terraform apply (13:15)** — 1h 8min before incident
   - Node pool autoscaling minimum changed 3→5
   - Could trigger new node provisioning
   - ⚠️ Cluster-level change

### Likely Cause

**Primary:** ConfigMap change (K8S) at 13:30
- Directly affects the application that was impacted
- 53-minute delay consistent with slow resource accumulation
- Config change without corresponding rollout is a known anti-pattern

**Secondary:** Helm upgrade at 12:45
- Infrastructure-level change
- Could have affected health check routing

### Integration with Incident Replay Engine

This correlation data feeds directly into the Incident Replay Engine:

```bash
# Export correlation to incident replay
./timeline/export-timeline.sh --incident INC-001 --format replay
```

---

## Scoring Algorithm

Each change is scored on 4 dimensions:

| Dimension | Weight | Description |
|-----------|--------|-------------|
| **Proximity** | 30% | How close in time to the incident (closer = higher) |
| **Impact Radius** | 25% | How many systems/components affected |
| **Change Type Risk** | 25% | Config change > deploy > code change > infra |
| **Author Familiarity** | 20% | Known risk patterns from past incidents |

### Risk Levels by Change Type

| Change Type | Base Risk | Rationale |
|------------|-----------|-----------|
| ConfigMap/Secret update | 8/10 | Live config change, no validation |
| Helm upgrade | 7/10 | Infrastructure-level change |
| Terraform apply | 6/10 | Cloud resource modification |
| Production deploy | 5/10 | Code change, usually tested |
| Cert rotation | 4/10 | Scheduled, usually safe |
| DNS change | 3/10 | Propagation delay, usually caught |
| Git commit (not deployed) | 1/10 | No production impact yet |

---

## Integration Points

### With Incident Replay Engine
- Feed change correlation as Layer 1 (Infrastructure State) data
- Auto-populate "What changed before the incident?"

### With Crisis Command Center
- Show recent changes in the dashboard
- Highlight high-risk changes during active incident

### With Context Graph SRE
- Cross-reference changes with past incident patterns
- "This exact change caused INC-004 last time"

---

## Roadmap

**Phase 1 (MVP):** ✅
- Git collector
- Pipeline collector
- Manual correlation
- Timeline generation

**Phase 2:**
- Kubernetes collector (events, deployments, configmaps)
- Helm collector
- Terraform collector
- Automated scoring

**Phase 3:**
- Azure Monitor collector
- Certificate collector
- DNS collector
- Real-time monitoring mode

**Phase 4:**
- Vector-based similarity (find past incidents with similar change patterns)
- Predictive scoring (warn BEFORE deploying risky changes)
- Cross-cluster correlation

---

## Why This Matters

**For Manav:**
- He manages Terraform pipelines, k8s deploys, and Azure resources
- Every incident starts with "what changed?"
- This automates the first 15 minutes of every investigation

**For SRE teams:**
- Reduces time to root cause
- Prevents repeat incidents
- Creates accountability (who changed what, when)

**For the ecosystem:**
- Completes the incident stack:
  - **Context Graph SRE** → Store decisions
  - **Incident Replay Engine** → Replay incidents
  - **Crisis Command Center** → Respond in real-time
  - **Change Correlator** → Find what caused it

---

## Philosophy

> If you can't see what changed, you can't fix what broke.

Every incident investigation starts with the same question. This tool answers it.
