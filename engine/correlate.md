# Correlation Engine

> Finds and scores all changes within a time window before an incident.

## Usage

```bash
# Find changes in 2h window before incident
bash engine/correlate.sh --incident-time "2026-04-12 14:23" --window "2h"

# With specific sources
bash engine/correlate.sh --incident-time "2026-04-12 14:23" --window "4h" --sources git,pipeline,k8s

# Save to specific output directory
bash engine/correlate.sh --incident-time "2026-04-12 14:23" --output ./my-analysis
```

## Scoring Algorithm

Each change is scored on 4 dimensions (0–100 total):

| Dimension | Weight | How It's Calculated |
|-----------|--------|-------------------|
| **Proximity** | 30pts | How close in time to the incident. Within 10min = 30, 2h = 10 |
| **Type Risk** | 25pts | ConfigMap = 25, Helm = 22, Terraform = 20, Pipeline = 18, Git = 12, Event = 5 |
| **Severity** | 20pts | high = 20, medium = 12, normal = 5 |
| **Base** | 25pts | Presence in the window = 15–25 depending on density |

### Risk Levels by Change Type

| Change Type | Base Risk | Rationale |
|------------|-----------|-----------|
| ConfigMap/Secret update | 25/25 | Live config change, no validation |
| Helm upgrade | 22/25 | Infrastructure-level change |
| Terraform apply | 20/25 | Cloud resource modification |
| Production deploy | 18/25 | Code change, usually tested |
| Git commit (not deployed) | 12/25 | No production impact yet |
| Certificate rotation | 10/25 | Scheduled, usually safe |
| DNS change | 10/25 | Propagation delay |
| k8s Event | 5/25 | Informational |

### Proximity Scoring

| Distance from incident | Score |
|----------------------|-------|
| ≤10 minutes | 30 |
| ≤30 minutes | 25 |
| ≤1 hour | 20 |
| ≤1.5 hours | 15 |
| >1.5 hours | 10 |

## Manual Correlation Process

### Step 1: Define the window

```bash
INCIDENT_TIME="2026-04-12 14:23"
WINDOW="2h"

# Convert to epoch for filtering
INCIDENT_EPOCH=$(date -d "$INCIDENT_TIME" +%s)
WINDOW_SECONDS=7200  # 2h
WINDOW_START=$((INCIDENT_EPOCH - WINDOW_SECONDS))

echo "Window: $(date -d @$WINDOW_START '+%Y-%m-%d %H:%M') → $(date -d @$INCIDENT_EPOCH '+%Y-%m-%d %H:%M')"
```

### Step 2: Collect changes from all sources

```bash
# Git
git -C /path/to/repo log --format='%H|%ai|%an|%s' --since="2 hours ago"

# Pipeline (Azure DevOps)
az pipelines runs list --top 50

# Kubernetes events
kubectl get events --sort-by='.lastTimestamp' -o json
```

### Step 3: Build the timeline

Sort all changes by timestamp, annotate with source and type:

```
12:15  [GIT]     abc1234  Update payment-api to v2.3.1           25/100
12:23  [PIPE]    #4521    Deploy payment-api → production         33/100
12:45  [HELM]    ingress  nginx-ingress 4.7.2 → 4.8.0           52/100
13:30  [K8S]     config   payment-api-config timeout 30→60s      80/100 ⚠️
14:23  ⚡ ALERT  3 nodes NotReady — INCIDENT START
```

### Step 4: Analyze top-scoring changes

For each change with score ≥ 70:
1. Check if it directly affects the impacted system
2. Look for precedent in incident replays
3. Determine if correlation = causation or coincidence
4. Document red herrings

### Step 5: Generate report

Create three files:
- `timeline.md` — Chronological view of all changes
- `correlation.md` — Scoring analysis + likely cause
- `changes.md` — Full details of each change

## Red Herring Detection

Not every change near an incident is the cause. Watch for:

| Pattern | What It Looks Like | Reality |
|---------|-------------------|---------|
| Coincidental deploy | Deploy 2h before incident | Root cause was 90-day disk accumulation |
| Benign config change | ConfigMap updated nearby | Change was unrelated to failure mode |
| Scheduled maintenance | Cert rotation during incident | Cert was fine, incident was unrelated |

**Rule:** Correlation is a hypothesis generator, not a conclusion maker. Always verify with system-level investigation.

## Integration with Other Tools

### Incident Replay Engine
```bash
# Export correlation to incident replay
cp samples/INC-001-correlation/ /path/to/incident-replay-engine/replays/INC-001/changes/
```

### Crisis Command Center
```bash
# Show recent changes during active incident
cat changes/2026-04-12/*.md | grep -A5 "timestamp:"
```

### Context Graph SRE
```bash
# Query for similar change patterns
grep -r "payment-api-config" /path/to/context-graph/
```
