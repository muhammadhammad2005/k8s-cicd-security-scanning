#!/bin/bash

REPORT_DIR="reports"
mkdir -p $REPORT_DIR

echo "Starting container image security scanning..."

IMAGES=(
    "nginx:1.14"
    "nginx:1.21-alpine"
)

for image in "${IMAGES[@]}"; do
    echo "Scanning image: $image"
    clean_name=$(echo $image | sed 's/[^a-zA-Z0-9]/_/g')
    
    trivy image --format json "$image" > "$REPORT_DIR/trivy-$clean_name.json"
    trivy image --format table "$image" > "$REPORT_DIR/trivy-$clean_name.txt"
    
    echo "Vulnerability summary for $image:"
    trivy image --format json "$image" | jq -r '
        [.Results[]?.Vulnerabilities // [] | .[]] |
        group_by(.Severity) |
        map({severity: .[0].Severity, count: length}) |
        .[] |
        "\(.severity): \(.count)"
    ' | sort
    
    echo "---"
done

echo "Image scanning complete. Reports saved in $REPORT_DIR/"
