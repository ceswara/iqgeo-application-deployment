#!/bin/bash
# Fix PVC: delete and let Helm recreate with ReadWriteOnce
# Run this on your Kubernetes server, then run: terraform apply (from iqgeo-application-deployment)

set -e

OUTPUT_FILE="fix-pvc-output.txt"

echo "=== Fix PVC Access Mode ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Scale deployment to 0 so PVC is not in use
echo "=== Scaling deployment to 0 ===" >> "$OUTPUT_FILE"
kubectl scale deployment iqgeo-platform -n iqgeo --replicas=0 >> "$OUTPUT_FILE" 2>&1
echo "Waiting 15s for pods to terminate..." >> "$OUTPUT_FILE"
sleep 15
echo "" >> "$OUTPUT_FILE"

# Delete the PVC (will be recreated by Helm with ReadWriteOnce on next terraform apply)
echo "=== Deleting PVC ===" >> "$OUTPUT_FILE"
kubectl delete pvc iqgeo-platform-shared-data -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "PVC already gone or error" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== Next step (run on server) ===" >> "$OUTPUT_FILE"
echo "  cd /path/to/iqgeo-application-deployment" >> "$OUTPUT_FILE"
echo "  terraform apply" >> "$OUTPUT_FILE"
echo "Helm upgrade will recreate the PVC with ReadWriteOnce and set replicas to 1." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== Current state ===" >> "$OUTPUT_FILE"
kubectl get pvc -n iqgeo >> "$OUTPUT_FILE" 2>&1
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
echo "Then run: terraform apply"
