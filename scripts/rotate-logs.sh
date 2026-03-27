#!/bin/bash
LOG_DIR="/var/log/app"
MAX_SIZE_MB=100
MAX_FILES=10
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -name "*.log" -type f | while read f; do
    size=$(stat -c%s "$f")
    if [ $((size/1024/1024)) -gt $MAX_SIZE_MB ]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        mv "$f" "${f}.${timestamp}"
        gzip "${f}.${timestamp}"
        touch "$f"
    fi
done
find "$LOG_DIR" -name "*.gz" | sort | head -n -$MAX_FILES | xargs rm -f
