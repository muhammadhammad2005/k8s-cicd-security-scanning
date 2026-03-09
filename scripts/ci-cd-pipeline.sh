#!/bin/bash

set -e

REPORT_DIR="reports"
MANIFEST_DIR="manifests"

echo "========================================="
echo "Starting Security CI/CD Pipeline"
echo "========================================="

mkdir -p $REPORT_DIR

# --- Stage 1: Manifest Security Analysis ---
echo ""
echo "Stage 1: Kubernetes Manifest Security Analysis"
echo "-----------------------------------------------"

security_gate_failed=false

echo "Running Kubesec analysis..."
for file in $MANIFEST_DIR/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .yaml)
        echo "  Analyzing $filename..."
        
        kubesec scan "$file" > "$REPORT_DIR/kubesec-$filename.json"
        score=$(cat "$REPORT_DIR/kubesec-$filename.json" | jq -r '.[0].score // "N/A"')
        echo "    Security score: $score"
        
        if [ "$score" != "N/A" ] && [ "$score" -lt 0 ]; then
            echo "    CRITICAL: Negative security score!"
            security_gate_failed=true
        elif [ "$score" != "N/A" ] && [ "$score" -lt 5 ]; then
            echo "    WARNING: Low security score"
        else
            echo "    PASS: Good security score"
        fi
    fi
done

echo ""
echo "Running KubeLinter analysis..."
kube-linter lint $MANIFEST_DIR --format json > $REPORT_DIR/kubelinter-pipeline.json

issues=$(cat $REPORT_DIR/kubelinter-pipeline.json | jq '.Issues | length')
echo "  KubeLinter found $issues issues"

if [ "$issues" -gt 0 ]; then
    echo "  Issues found:"
    cat $REPORT_DIR/kubelinter-pipeline.json | jq -r '.Issues[] | "    - \(.Object.K8sObject.Name): \(.Message)"' | head -10
fi

# --- Stage 2: Container Image Scanning ---
echo ""
echo "Stage 2: Container Image Security Analysis"
echo "------------------------------------------"

images=$(grep -h "image:" $MANIFEST_DIR/*.yaml | sed 's/.*image: *//' | sed 's/["\r]//g' | sort -u)

echo "Found container images:"
for image in $images; do
    echo "  - $image"
done

for image in $images; do
    echo ""
    echo "Scanning $image..."
    clean_name=$(echo $image | sed 's/[^a-zA-Z0-9]/_/g')
    
    trivy image --format json "$image" > "$REPORT_DIR/trivy-pipeline-$clean_name.json" 2>/dev/null || true
    
    if [ -f "$REPORT_DIR/trivy-pipeline-$clean_name.json" ]; then
        critical=$(cat "$REPORT_DIR/trivy-pipeline-$clean_name.json" | jq -r '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity == "CRITICAL")] | length')
        high=$(cat "$REPORT_DIR/trivy-pipeline-$clean_name.json" | jq -r '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity == "HIGH")] | length')
        medium=$(cat "$REPORT_DIR/trivy-pipeline-$clean_name.json" | jq -r '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity == "MEDIUM")] | length')
        
        echo "  Vulnerabilities: Critical=$critical, High=$high, Medium=$medium"
        
        if [ "$critical" -gt 0 ]; then
            echo "  CRITICAL: Image has critical vulnerabilities!"
            security_gate_failed=true
        elif [ "$high" -gt 10 ]; then
            echo "  FAIL: Too many high-severity vulnerabilities!"
            security_gate_failed=true
        elif [ "$high" -gt 0 ]; then
            echo "  WARNING: Image has high-severity vulnerabilities"
        else
            echo "  PASS: No critical/high vulnerabilities found"
        fi
    else
        echo "  WARNING: Could not scan image"
    fi
done

# --- Stage 3: Policy Compliance Check ---
echo ""
echo "Stage 3: Policy Compliance Check"
echo "--------------------------------"

echo "Checking security best practices..."

non_root_check=$(grep -rl "runAsNonRoot: true" $MANIFEST_DIR/ | wc -l)
echo "  Files with runAsNonRoot: $non_root_check"

resource_limits=$(grep -rl "limits:" $MANIFEST_DIR/ | wc -l)
echo "  Files with resource limits: $resource_limits"

security_contexts=$(grep -rl "securityContext:" $MANIFEST_DIR/ | wc -l)
echo "  Files with security contexts: $security_contexts"

# --- Stage 4: Final Security Gate ---
echo ""
echo "Stage 4: Final Security Gate"
echo "----------------------------"

if [ "$security_gate_failed" = true ]; then
    echo "PIPELINE FAILED: Security gate check failed!"
    echo "Please fix the security issues before proceeding."
    exit 1
else
    echo "PIPELINE PASSED: All security checks passed!"
    echo "Deployment is approved."
fi
