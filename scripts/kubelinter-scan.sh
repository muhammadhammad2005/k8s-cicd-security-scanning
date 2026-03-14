#!/bin/bash

MANIFEST_DIR="manifests"
REPORT_DIR="reports"

# Check dependencies
if ! command -v kube-linter &> /dev/null; then
    echo "Error: kube-linter is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

echo "Starting KubeLinter security analysis..."
mkdir -p $REPORT_DIR

kube-linter lint $MANIFEST_DIR --format json > $REPORT_DIR/kubelinter-full.json
kube-linter lint $MANIFEST_DIR > $REPORT_DIR/kubelinter-summary.txt
kube-linter lint $MANIFEST_DIR --format sarif > $REPORT_DIR/kubelinter-sarif.json

echo "Issue Summary:"
echo "==============="

if [ -f "$REPORT_DIR/kubelinter-full.json" ]; then
    total_issues=$(cat $REPORT_DIR/kubelinter-full.json | jq '.Issues | length')
    echo "Total issues found: $total_issues"

    echo "Issues by type:"
    cat $REPORT_DIR/kubelinter-full.json | jq -r '.Issues[] | .Check' | sort | uniq -c | sort -nr
else
    echo "No issues data available"
fi

echo "KubeLinter analysis complete. Reports saved in $REPORT_DIR/"
