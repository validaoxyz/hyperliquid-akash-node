#!/bin/bash
DATA_PATH="${HL_DATA_PATH:-${HOME:-/home/hluser}/hl/data}"

# Log startup for debugging
echo "$(date): Prune script started" >> /proc/1/fd/1

# Check if data directory exists
if [ ! -d "$DATA_PATH" ]; then
    echo "$(date): Warning: Data directory $DATA_PATH does not exist yet. Skipping pruning." >> /proc/1/fd/1
    exit 0
fi

echo "$(date): Starting pruning process at $(date)" >> /proc/1/fd/1

# Get directory size before pruning
size_before=$(du -sh "$DATA_PATH" | cut -f1)
files_before=$(find "$DATA_PATH" -type f | wc -l)
echo "$(date): Size before pruning: $size_before with $files_before files" >> /proc/1/fd/1

# Delete files older than 1 hour (60 minutes)
MAX_MINUTES=60
find "$DATA_PATH" -mindepth 1 -depth -mmin +$MAX_MINUTES -type f -delete

# Get directory size after pruning
size_after=$(du -sh "$DATA_PATH" | cut -f1)
files_after=$(find "$DATA_PATH" -type f | wc -l)
echo "$(date): Size after pruning: $size_after with $files_after files" >> /proc/1/fd/1
echo "$(date): Pruning completed. Reduced from $size_before to $size_after ($(($files_before - $files_after)) files removed)." >> /proc/1/fd/1
