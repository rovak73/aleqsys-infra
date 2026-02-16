#!/bin/bash
set -e

THRESHOLD=${DISK_THRESHOLD:-90}
SLACK_URL=${SLACK_WEBHOOK_URL:-""}

echo "Starting disk monitor. Threshold: ${THRESHOLD}%"

# Clean up Docker resources first
if command -v docker &> /dev/null; then
  echo "Running Docker cleanup..."
  docker system prune -f --volumes 2>/dev/null || true
  docker image prune -f 2>/dev/null || true
  docker volume prune -f 2>/dev/null || true
else
  echo "Docker not found, skipping cleanup."
fi

USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
echo "Current disk usage: ${USAGE}%"

if [ "$USAGE" -ge "$THRESHOLD" ]; then
  MESSAGE="ALERT: Disk usage on $(hostname) is at ${USAGE}% (Threshold: ${THRESHOLD}%)"
  echo "$MESSAGE"
  
  if [ -n "$SLACK_URL" ]; then
    echo "Sending Slack notification..."
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$MESSAGE\"}" "$SLACK_URL" || echo "Failed to send Slack notification"
  fi
  
  exit 1
fi

echo "Disk usage is within limits."
exit 0
