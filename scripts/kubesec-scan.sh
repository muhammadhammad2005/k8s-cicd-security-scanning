#!/bin/bash

MANIFEST_DIR="manifests"
REPORT_DIR="reports"

echo "Starting Kubesec security analysis..."
mkdir -p $REPORT_DIR

for file in $MANIFEST_DIR/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .yaml)
        echo "Scanning $file..."
        
        kubesec scan "$file" > "$REPORT_DIR/kubesec-$filename.json"
        
        score=$(cat "$REPORT_DIR/kubesec-$filename.json" | jq -r '.[0].score // "N/A"')
        echo "Security score for $filename: $score"
        
        if [ "$score" != "N/A" ] && [ "$score" -lt 0 ]; then
            echo "WARNING: $filename has a negative security score!"
            echo "Critical issues found:"
            cat "$REPORT_DIR/kubesec-$filename.json" | jq -r '.[0].scoring.critical[]?.reason // empty'
        fi
        echo "---"
    fi
done

echo "Kubesec analysis complete. Reports saved in $REPORT_DIR/"
