#!/bin/bash
# Log Rotation Script
# Runs on EC2 instances to rotate logs

set -euo pipefail

LOG_DIR="/var/log/app"
MAX_SIZE_MB=100
MAX_FILES=10

echo "Starting log rotation..."

mkdir -p "$LOG_DIR"

find "$LOG_DIR" -name "*.log" -type f | while read -r logfile; do
    if [ -f "$logfile" ]; then
        size=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
        size_mb=$((size / 1024 / 1024))
        if [ $size_mb -gt $MAX_SIZE_MB ]; then
            echo "Rotating $logfile (size: ${size_mb}MB)"
            timestamp=$(date +%Y%m%d_%H%M%S)
            mv "$logfile" "${logfile}.${timestamp}"
            gzip "${logfile}.${timestamp}"
            touch "$logfile"
            chmod 644 "$logfile"
            echo "Rotated: ${logfile}.${timestamp}.gz"
        fi
    fi
done

echo "Cleaning old log files..."
find "$LOG_DIR" -name "*.gz" -type f | sort | head -n -$MAX_FILES | while read -r oldfile; do
    echo "Deleting old log: $oldfile"
    rm -f "$oldfile"
done

echo "Log rotation completed"
