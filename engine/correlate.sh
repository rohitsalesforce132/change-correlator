#!/bin/bash
# Change Correlation Engine
# Finds and scores all changes within a time window before an incident
# Usage: bash engine/correlate.sh --incident-time "2026-04-12 14:23" --window "2h"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGES_DIR="$PROJECT_DIR/changes"
SAMPLES_DIR="$PROJECT_DIR/samples"

INCIDENT_TIME=""
WINDOW="2h"
SOURCES=""
OUTPUT_DIR=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --incident-time) INCIDENT_TIME="$2"; shift ;;
        --window) WINDOW="$2"; shift ;;
        --sources) SOURCES="$2"; shift ;;
        --output) OUTPUT_DIR="$2"; shift ;;
        --incident) OUTPUT_DIR="$SAMPLES_DIR/$2-correlation"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$INCIDENT_TIME" ]; then
    echo "Usage: bash correlate.sh --incident-time <timestamp> [--window <duration>] [--sources <list>] [--output <dir>]"
    echo ""
    echo "Examples:"
    echo "  bash correlate.sh --incident-time '2026-04-12 14:23' --window '2h'"
    echo "  bash correlate.sh --incident-time '2026-04-12 14:23' --sources git,pipeline,k8s"
    echo "  bash correlate.sh --incident-time '2026-04-12 14:23' --incident INC-001"
    exit 1
fi

# Convert incident time to epoch
INCIDENT_EPOCH=$(date -d "$INCIDENT_TIME" +%s 2>/dev/null)
if [ -z "$INCIDENT_EPOCH" ]; then
    echo "❌ Could not parse incident time: $INCIDENT_TIME"
    echo "   Try format: 'YYYY-MM-DD HH:MM'"
    exit 1
fi

# Calculate window start
WINDOW_SECONDS=$(echo "$WINDOW" | sed 's/h/*3600/;s/m/*60/;s/d/*86400/;s/s//' | bc 2>/dev/null || echo 7200)
WINDOW_START_EPOCH=$((INCIDENT_EPOCH - WINDOW_SECONDS))

echo "🔗 Change Correlation Engine"
echo "════════════════════════════"
echo "   Incident Time: $INCIDENT_TIME"
echo "   Window: $WINDOW before incident"
echo "   Window Range: $(date -d @$WINDOW_START_EPOCH '+%Y-%m-%d %H:%M') → $(date -d @$INCIDENT_EPOCH '+%Y-%m-%d %H:%M')"
echo ""

# Create output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$SAMPLES/incident-$(date -d @$INCIDENT_EPOCH +%Y%m%d-%H%M)-correlation"
fi
mkdir -p "$OUTPUT_DIR"

# Collect all changes in window
declare -a CORRELATED_CHANGES

for change_file in $(find "$CHANGES_DIR" -name "*.md" -type f 2>/dev/null); do
    # Extract timestamp from change file
    timestamp=$(grep "^timestamp:" "$change_file" | awk '{print $2" "$3}' | sed 's/"//g')
    
    if [ -z "$timestamp" ]; then
        continue
    fi
    
    # Convert to epoch
    change_epoch=$(date -d "$timestamp" +%s 2>/dev/null || continue)
    
    # Check if within window
    if [ "$change_epoch" -ge "$WINDOW_START_EPOCH" ] && [ "$change_epoch" -le "$INCIDENT_EPOCH" ]; then
        # Filter by source if specified
        if [ -n "$SOURCES" ]; then
            source=$(grep "^source:" "$change_file" | awk '{print $2}')
            if ! echo "$SOURCES" | grep -q "$source"; then
                continue
            fi
        fi
        
        CORRELATED_CHANGES+=("$change_file")
    fi
done

if [ ${#CORRELATED_CHANGES[@]} -eq 0 ]; then
    echo "⚠️  No changes found in the specified window."
    echo ""
    echo "   Run collectors first:"
    echo "   ./collectors/git-collector.sh --repo /path/to/repo --since '$WINDOW ago'"
    echo "   ./collectors/pipeline-collector.sh --pipeline <name> --since '$WINDOW ago'"
    echo "   ./collectors/k8s-collector.sh --cluster <cluster> --since '$WINDOW ago'"
    exit 0
fi

echo "Found ${#CORRELATED_CHANGES[@]} changes in window:"
echo ""

# Score each change
declare -a SCORED_CHANGES

for change_file in "${CORRELATED_CHANGES[@]}"; do
    change_id=$(grep "^id:" "$change_file" | awk '{print $2}')
    source=$(grep "^source:" "$change_file" | awk '{print $2}')
    timestamp=$(grep "^timestamp:" "$change_file" | awk '{print $2" "$3}' | sed 's/"//g')
    severity=$(grep "^severity:" "$change_file" | awk '{print $2}')
    
    change_epoch=$(date -d "$timestamp" +%s 2>/dev/null || continue)
    
    # Calculate proximity score (0-30)
    distance=$((INCIDENT_EPOCH - change_epoch))
    if [ "$distance" -le 600 ]; then
        proximity_score=30  # Within 10 min
    elif [ "$distance" -le 1800 ]; then
        proximity_score=25  # Within 30 min
    elif [ "$distance" -le 3600 ]; then
        proximity_score=20  # Within 1h
    elif [ "$distance" -le 5400 ]; then
        proximity_score=15  # Within 1.5h
    else
        proximity_score=10  # 1.5-2h
    fi
    
    # Calculate type risk score (0-25)
    kind=$(grep "^kind:" "$change_file" | awk '{print $2}')
    case "$source:$kind" in
        *:ConfigMap|*:Secret) type_score=25 ;;
        *:Helm|helm:*) type_score=22 ;;
        terraform:*) type_score=20 ;;
        pipeline:*) type_score=18 ;;
        kubernetes:Deployment) type_score=15 ;;
        git:*) type_score=12 ;;
        *:Certificate|cert:*) type_score=10 ;;
        *:Event) type_score=5 ;;
        *) type_score=10 ;;
    esac
    
    # Severity boost (0-20)
    case "$severity" in
        high) severity_score=20 ;;
        medium) severity_score=12 ;;
        normal|low) severity_score=5 ;;
        *) severity_score=5 ;;
    esac
    
    # Base score for being in the window (0-25)
    base_score=15
    
    # Total score
    total_score=$((proximity_score + type_score + severity_score + base_score))
    [ "$total_score" -gt 100 ] && total_score=100
    
    SCORED_CHANGES+=("$total_score|$change_id|$source|$timestamp|$severity|$change_file")
done

# Sort by score (descending)
IFS=$'\n' SORTED_CHANGES=($(sort -t'|' -k1 -rn <<< "${SCORED_CHANGES[*]}")); unset IFS

# Generate correlation report
TIMELINE_FILE="$OUTPUT_DIR/timeline.md"
CORRELATION_FILE="$OUTPUT_DIR/correlation.md"
CHANGES_FILE="$OUTPUT_DIR/changes.md"

# Timeline
cat > "$TIMELINE_FILE" <<EOF
# Change Timeline

**Incident Time:** $INCIDENT_TIME
**Window:** $WINDOW before incident
**Changes Found:** ${#SORTED_CHANGES[@]}

---

## Timeline

| Time | Source | Change | Risk Score |
|------|--------|--------|-----------|
EOF

for entry in "${SORTED_CHANGES[@]}"; do
    score=$(echo "$entry" | cut -d'|' -f1)
    change_id=$(echo "$entry" | cut -d'|' -f2)
    source=$(echo "$entry" | cut -d'|' -f3)
    timestamp=$(echo "$entry" | cut -d'|' -f4)
    change_file=$(echo "$entry" | cut -d'|' -f6)
    
    # Extract description from file
    description=$(grep "^# " "$change_file" | head -1 | sed 's/^# //')
    
    risk_indicator=""
    [ "$score" -ge 70 ] && risk_indicator="⚠️"
    [ "$score" -ge 85 ] && risk_indicator="🔴"
    
    echo "| $(date -d "$timestamp" '+%H:%M' 2>/dev/null || echo "$timestamp") | $source | $description | $score/100 $risk_indicator |" >> "$TIMELINE_FILE"
done

echo "" >> "$TIMELINE_FILE"
echo "---" >> "$TIMELINE_FILE"
echo "*Generated by Change Correlator on $(date '+%Y-%m-%d %H:%M')*" >> "$TIMELINE_FILE"

# Correlation analysis
TOP_CHANGE=$(echo "${SORTED_CHANGES[0]}" | cut -d'|' -f6)
TOP_SCORE=$(echo "${SORTED_CHANGES[0]}" | cut -d'|' -f1)
TOP_ID=$(echo "${SORTED_CHANGES[0]}" | cut -d'|' -f2)

cat > "$CORRELATION_FILE" <<EOF
# Correlation Analysis

**Incident Time:** $INCIDENT_TIME
**Changes in Window:** ${#SORTED_CHANGES[@]}

---

## Highest Risk Changes

EOF

# Top 3 changes
for i in 0 1 2; do
    [ $i -ge ${#SORTED_CHANGES[@]} ] && break
    
    entry="${SORTED_CHANGES[$i]}"
    score=$(echo "$entry" | cut -d'|' -f1)
    change_id=$(echo "$entry" | cut -d'|' -f2)
    source=$(echo "$entry" | cut -d'|' -f3)
    timestamp=$(echo "$entry" | cut -d'|' -f4)
    change_file=$(echo "$entry" | cut -d'|' -f6)
    
    description=$(grep "^# " "$change_file" | head -1 | sed 's/^# //')
    what_changed=$(grep -A5 "^## What Changed" "$change_file" | tail -n +2 | head -3)
    
    echo "### ${i+1}. $change_id (Score: $score/100)" >> "$CORRELATION_FILE"
    echo "" >> "$CORRELATION_FILE"
    echo "**Source:** $source" >> "$CORRELATION_FILE"
    echo "**Time:** $timestamp" >> "$CORRELATION_FILE"
    echo "**Description:** $description" >> "$CORRELATION_FILE"
    echo "" >> "$CORRELATION_FILE"
    echo "What Changed:" >> "$CORRELATION_FILE"
    echo "$what_changed" >> "$CORRELATION_FILE"
    echo "" >> "$CORRELATION_FILE"
    echo "---" >> "$CORRELATION_FILE"
    echo "" >> "$CORRELATION_FILE"
done

# Likely cause
echo "## Likely Cause" >> "$CORRELATION_FILE"
echo "" >> "$CORRELATION_FILE"
top_desc=$(grep "^# " "$TOP_CHANGE" | head -1 | sed 's/^# //')
echo "**Primary:** $top_desc (Score: $TOP_SCORE/100)" >> "$CORRELATION_FILE"
echo "" >> "$CORRELATION_FILE"

# Print summary
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  CORRELATION RESULTS                                         │"
echo "├──────────────────────────────────────────────────────────────┤"
echo ""

for entry in "${SORTED_CHANGES[@]}"; do
    score=$(echo "$entry" | cut -d'|' -f1)
    change_id=$(echo "$entry" | cut -d'|' -f2)
    source=$(echo "$entry" | cut -d'|' -f3)
    timestamp=$(echo "$entry" | cut -d'|' -f4)
    change_file=$(echo "$entry" | cut -d'|' -f6)
    
    description=$(grep "^# " "$change_file" | head -1 | sed 's/^# //')
    
    if [ "$score" -ge 70 ]; then
        indicator="⚠️ "
    elif [ "$score" -ge 50 ]; then
        indicator="🟡"
    else
        indicator="✅"
    fi
    
    printf "  %s %-20s [%-5s] %3d/100  %s\n" "$indicator" "$change_id" "$source" "$score" "${description:0:40}"
done

echo ""
echo "📁 Full analysis saved to: $OUTPUT_DIR/"
echo "   - timeline.md"
echo "   - correlation.md"
echo "   - changes.md"
