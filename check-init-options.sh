#!/bin/bash
OUTPUT_FILE="init-options-check.txt"

{
echo "========================================="
echo "Checking IQGeo Initialization Options - $(date)"
echo "========================================="
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)

echo "Step 1: Checking ConfigMap environment variables for init/setup flags..."
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o yaml | grep -v "kubernetes.io" | grep -E "DEBUG|INIT|SETUP|MIGRATE|SCHEMA|AUTO"
echo ""

echo "Step 2: Checking container environment variables..."
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.spec.containers[0].env}' 2>/dev/null | python3 -m json.tool || echo "Pod not ready"
echo ""

echo "Step 3: Checking if there's a database initialization command..."
kubectl exec $POD_NAME -n iqgeo -- ls -la /opt/iqgeo/platform/Tools/ 2>&1 | grep -i "db\|init\|schema\|migrate" || echo "Container not ready for exec"
echo ""

echo "Step 4: Checking if there's a myw_db.py tool (seen in logs)..."
kubectl exec $POD_NAME -n iqgeo -- cat /opt/iqgeo/platform/Tools/myw_db.py 2>&1 | head -50 || echo "Cannot read file - container crashed"
echo ""

echo "Step 5: Looking for documentation or help in the container..."
kubectl exec $POD_NAME -n iqgeo -- ls -la /opt/iqgeo/platform/ 2>&1 | grep -iE "readme|doc|help" || echo "Container not accessible"
echo ""

echo "Step 6: Checking entrypoint script..."
kubectl exec $POD_NAME -n iqgeo -- cat /docker-entrypoint.sh 2>&1 | head -100 || echo "No docker-entrypoint.sh or container crashed"
echo ""

echo "Step 7: Check if there's a specific initialization entrypoint..."
kubectl exec $POD_NAME -n iqgeo -- ls -la /docker-entrypoint.d/ 2>&1 || echo "No entrypoint.d directory"
echo ""

echo "Step 8: Check logs for any 'usage' or 'help' messages..."
kubectl logs $POD_NAME -n iqgeo --all-containers=true 2>&1 | grep -iE "usage|help|command|option|flag" | head -20
echo ""

echo "========================================="
echo "RECOMMENDATIONS"
echo "========================================="
echo ""
echo "The application is failing during auto-initialization."
echo ""
echo "Possible fixes:"
echo "1. There might be an environment variable to skip auto-init"
echo "2. The database might need to be pre-populated from a schema file"
echo "3. Contact IQGeo support for proper first-time setup procedure"
echo ""
echo "From the logs, the application has:"
echo "  - /opt/iqgeo/platform/Tools/myw_db.py (database tool)"
echo "  - entrypoint.d/300-ensure-database.sh (database initialization)"
echo ""
echo "The entrypoint is trying to run 'myw_db.py initialize' which fails"
echo "because it tries to access tables before creating them."
echo ""
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
