# Kubernetes Change Collector

> Extracts k8s events, deployment changes, and config modifications.

## Events

```bash
# Get all recent events (sorted by time)
kubectl get events --sort-by='.lastTimestamp' -o json

# Events in a specific namespace
kubectl get events -n production --sort-by='.lastTimestamp' -o json

# Events for a specific resource
kubectl get events --field-selector involvedObject.name=node-worker-03 -o json

# Warning events only
kubectl get events --field-selector type=Warning -o json

# Events from last hour (requires jq)
kubectl get events --sort-by='.lastTimestamp' -o json | \
  jq '.items[] | select(.lastTimestamp > (now - 3600 | todate))'
```

## Deployments

```bash
# List all deployments with images
kubectl get deployments -o json | jq '.items[] | {name: .metadata.name, image: .spec.template.spec.containers[0].image, replicas: .spec.replicas}'

# Check rollout history
kubectl rollout history deployment/payment-api

# Check rollout status
kubectl rollout status deployment/payment-api

# Get deployment conditions
kubectl get deployment payment-api -o jsonpath='{.status.conditions}'
```

## ConfigMaps & Secrets

```bash
# List configmaps with last update
kubectl get configmaps -o json | jq '.items[] | {name: .metadata.name, namespace: .metadata.namespace, resourceVersion: .metadata.resourceVersion}'

# Get specific configmap data
kubectl get configmap payment-api-config -o yaml

# Check if configmap changed recently (compare resourceVersion)
kubectl get configmap payment-api-config -o jsonpath='{.metadata.resourceVersion}'

# Diff configmap versions
kubectl diff -f payment-api-config-new.yaml
```

## Building a Change File

For each k8s event or change, create a Markdown file in `changes/YYYY-MM-DD/`:

```markdown
---
id: CHG-K8S-CONFIG-20260412-1330
timestamp: 2026-04-12T13:30:00+05:30
source: kubernetes
severity: high
cluster: prod-cluster
namespace: production
kind: ConfigMap
object: payment-api-config
tags: [kubernetes, configmap, payment-api]
related_incidents: []
---

# K8s ConfigMap Update: payment-api-config

**Type:** Kubernetes ConfigMap Change
**Cluster:** prod-cluster
**Namespace:** production
**ConfigMap:** payment-api-config
**Time:** 2026-04-12 13:30 IST

## What Changed
- timeout: 30s → 60s
- health_check_interval: 10s → 20s

## Before
timeout: "30"
health_check_interval: "10"

## After
timeout: "60"
health_check_interval: "20"

## Affected Workloads
- deployment/payment-api (3 replicas)
```

## Severity Detection

| k8s Event Reason | Severity |
|-----------------|----------|
| Failed, Error, BackOff, Unhealthy | high |
| Killing, Evicted, OOMKilled | high |
| FailedScheduling, InsufficientCPU | medium |
| ScalingReplicaSet, Updated | normal |
| Started, Created, Pulled | low |

## Quick Commands

```bash
# Get all configmap changes in last hour
kubectl get events --field-selector involvedObject.kind=ConfigMap --sort-by='.lastTimestamp'

# Get deployment rollout history
kubectl rollout history deployment/payment-api --revision=3

# Check replica set changes (shows rollout history)
kubectl get rs -l app=payment-api -o wide

# Get resource usage per node
kubectl top nodes

# Get pod restart counts
kubectl get pods -o json | jq '.items[] | {name: .metadata.name, restarts: .status.containerStatuses[0].restartCount}'
```
