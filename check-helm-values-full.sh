#!/bin/bash
# Check what Helm values are actually being applied
# Run this on your Kubernetes server

OUTPUT_FILE="helm-values-full.txt"

echo "=== Helm Values Full Check ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get ALL computed values (user + defaults)
echo "=== ALL VALUES (computed, includes defaults) ===" >> "$OUTPUT_FILE"
helm get values iqgeo -n iqgeo --all >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Get just user-supplied values
echo "=== USER-SUPPLIED VALUES ONLY ===" >> "$OUTPUT_FILE"
helm get values iqgeo -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check PVC manifest from Helm
echo "=== PVC MANIFEST FROM HELM ===" >> "$OUTPUT_FILE"
helm get manifest iqgeo -n iqgeo | grep -A 30 "kind: PersistentVolumeClaim" >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check Deployment manifest from Helm (replicas)
echo "=== DEPLOYMENT MANIFEST FROM HELM (replicas section) ===" >> "$OUTPUT_FILE"
helm get manifest iqgeo -n iqgeo | grep -A 10 "kind: Deployment" | grep -A 10 "name: iqgeo-platform" >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file."
