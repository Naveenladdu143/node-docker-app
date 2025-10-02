#!/usr/bin/env bash
THRESHOLD=${1:-80}
echo "Checking disks; threshold ${THRESHOLD}%"
df -hP --exclude-type=tmpfs --exclude-type=devtmpfs | tail -n +2 | while read -r filesystem size used avail usep mount; do
  p=$(echo "$usep" | tr -d '%')
  if [ "$p" -ge "$THRESHOLD" ]; then
    echo "ALERT: $mount is ${usep} used"
  fi
done
