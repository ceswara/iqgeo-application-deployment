#!/bin/bash
# Check Harbor secret and test image pull
# Run this on your Kubernetes server

OUTPUT_FILE="harbor-secret-check.txt"

echo "=== Harbor Secret Check ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check if secret exists
echo "=== Harbor Secret Info ===" >> "$OUTPUT_FILE"
kubectl get secret harbor-repository -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Decode secret to see structure (remove password for security)
echo "=== Secret Content (dockerconfigjson structure) ===" >> "$OUTPUT_FILE"
kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths | keys' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Test Harbor login with the credentials from terraform.tfvars
echo "=== Testing Harbor Login ===" >> "$OUTPUT_FILE"
echo "Using credentials: robot\$techwave / (password hidden)" >> "$OUTPUT_FILE"
echo '6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg' | docker login harbor.delivery.iqgeo.cloud -u 'robot$techwave' --password-stdin >> "$OUTPUT_FILE" 2>&1
DOCKER_LOGIN_STATUS=$?
if [ $DOCKER_LOGIN_STATUS -eq 0 ]; then
    echo "✅ Docker login successful" | tee -a "$OUTPUT_FILE"
    
    # Try to pull the image
    echo "" >> "$OUTPUT_FILE"
    echo "=== Testing Image Pull ===" >> "$OUTPUT_FILE"
    docker pull harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3 >> "$OUTPUT_FILE" 2>&1
    PULL_STATUS=$?
    if [ $PULL_STATUS -eq 0 ]; then
        echo "✅ Image pull successful" | tee -a "$OUTPUT_FILE"
    else
        echo "❌ Image pull failed" | tee -a "$OUTPUT_FILE"
    fi
else
    echo "❌ Docker login failed" | tee -a "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# Check if harbor-repository secret was created by prerequisites
echo "=== Check Prerequisites Harbor Secret ===" >> "$OUTPUT_FILE"
kubectl get secret -n iqgeo | grep harbor >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
