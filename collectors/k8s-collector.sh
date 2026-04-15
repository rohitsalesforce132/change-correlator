#!/bin/bash
# Kubernetes Change Collector
# Extracts k8s events, deployments, and config changes
# Usage: bash collectors/k8s-collector.sh --cluster prod-cluster --since "2 hours ago"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGES_DIR="$PROJECT_DIR/changes"

CLUSTER=""
SINCE=""
NAMESPACE=""
RESOURCE_TYPE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cluster) CLUSTER="$2"; shift ;;
        --since) SINCE="$2"; shift ;;
        --namespace) NAMESPACE="$2"; shift ;;
        --type) RESOURCE_TYPE="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "🔍 Collecting Kubernetes changes"
[ -n "$CLUSTER" ] && echo "   Cluster: $CLUSTER"
[ -n "$NAMESPACE" ] && echo "   Namespace: $NAMESPACE"
echo ""

if ! command -v kubectl &>/dev/null; then
    echo "❌ kubectl not found. Install kubectl first."
    exit 1
fi

COUNT=0
TODAY=$(date +%Y-%m-%d)
change_dir="$CHANGES_DIR/$TODAY"
mkdir -p "$change_dir"

# Collect recent events
echo "📡 Collecting k8s events..."
NS_ARG=""
[ -n "$NAMESPACE" ] && NS_ARG="-n $NAMESPACE"

EVENTS=$(kubectl get events $NS_ARG --sort-by='.lastTimestamp' -o json 2>/dev/null || echo "[]")

echo "$EVENTS" | jq -c '.items[] | select(.lastTimestamp != null)' 2>/dev/null | while read -r event; do
    event_type=$(echo "$event" | jq -r '.type // "Normal"')
    event_reason=$(echo "$event" | jq -r '.reason // "Unknown"')
    event_message=$(echo "$event" | jq -r '.message // "No message"')
    event_object=$(echo "$event" | jq -r '.involvedObject.name // "Unknown"')
    event_kind=$(echo "$event" | jq -r '.involvedObject.kind // "Unknown"')
    event_namespace=$(echo "$event" | jq -r '.involvedObject.namespace // "default"')
    event_time=$(echo "$event" | jq -r '.lastTimestamp // .firstTimestamp // "unknown"')
    event_source=$(echo "$event" | jq -r '.source.component // "unknown"')
    
    # Skip if too old
    if [ -n "$SINCE" ]; then
        event_epoch=$(date -d "$event_time" +%s 2>/dev/null || echo "0")
        since_epoch=$(date -d "$SINCE" +%s 2>/dev/null || date -d "2 hours ago" +%s)
        [ "$event_epoch" -lt "$since_epoch" ] && continue
    fi
    
    change_time_clean=$(echo "$event_time" | tr -d 'T:' | cut -c1-15 | tr -d '-')
    change_id="CHG-K8S-EVT-${change_time_clean}"
    
    severity="normal"
    [ "$event_type" = "Warning" ] && severity="high"
    echo "$event_reason" | grep -qi "failed\|error\|backoff\|unhealthy" && severity="high"
    
    cat > "$change_dir/${change_id}.md" <<EOF
---
id: $change_id
timestamp: $event_time
source: kubernetes
severity: $severity
cluster: $CLUSTER
namespace: $event_namespace
kind: $event_kind
object: $event_object
reason: $event_reason
type: $event_type
tags: [kubernetes, event, $event_kind, $event_reason]
related_incidents: []
---

# K8s Event: $event_reason

**Type:** Kubernetes Event ($event_type)
**Cluster:** $CLUSTER
**Namespace:** $event_namespace
**Kind:** $event_kind
**Object:** $event_object
**Reason:** $event_reason
**Source:** $event_source
**Time:** $event_time

## What Happened
$event_message

## Object Details
- Kind: $event_kind
- Name: $event_object
- Namespace: $event_namespace
EOF
    
    echo "  ✅ $change_id: [$event_type] $event_reason on $event_object"
done

# Collect recent deployment changes
echo ""
echo "🚀 Collecting deployment changes..."

kubectl get deployments $NS_ARG -o json 2>/dev/null | \
jq -c '.items[] | select(.status.updatedReplicas != null)' 2>/dev/null | while read -r deploy; do
    deploy_name=$(echo "$deploy" | jq -r '.metadata.name')
    deploy_namespace=$(echo "$deploy" | jq -r '.metadata.namespace')
    deploy_replicas=$(echo "$deploy" | jq -r '.spec.replicas')
    deploy_updated=$(echo "$deploy" | jq -r '.status.updatedReplicas // 0')
    deploy_image=$(echo "$deploy" | jq -r '.spec.template.spec.containers[0].image // "unknown"')
    deploy_created=$(echo "$deploy" | jq -r '.metadata.creationTimestamp // "unknown"')
    
    change_id="CHG-K8S-DEP-${deploy_name}-${TODAY//-/}"
    
    cat > "$change_dir/${change_id}.md" <<EOF
---
id: $change_id
timestamp: $deploy_created
source: kubernetes
severity: normal
cluster: $CLUSTER
namespace: $deploy_namespace
kind: Deployment
object: $deploy_name
image: $deploy_image
replicas: $deploy_replicas
updated: $deploy_updated
tags: [kubernetes, deployment, $deploy_name]
related_incidents: []
---

# K8s Deployment: $deploy_name

**Type:** Kubernetes Deployment
**Cluster:** $CLUSTER
**Namespace:** $deploy_namespace
**Name:** $deploy_name
**Image:** $deploy_image
**Replicas:** $deploy_replicas (updated: $deploy_updated)
**Created:** $deploy_created

## Current State
- Image: $deploy_image
- Replicas: $deploy_replicas
- Updated Replicas: $deploy_updated
EOF
    
    echo "  ✅ $change_id: $deploy_name ($deploy_image)"
done

echo ""
echo "📊 Kubernetes change collection complete."
