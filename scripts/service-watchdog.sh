#!/bin/bash

SYSTEMD_SERVICES="aleqsys-production aleqsys-staging celery-worker celery-beat caddy"
DOCKER_SERVICES="phoenix n8n"
RESTART_FAILED=${WATCHDOG_RESTART:-false}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OVERALL="healthy"
SERVICES_JSON="{"

FIRST=true

# Check systemd services
for SERVICE in $SYSTEMD_SERVICES; do
    STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null)
    if [ -z "$STATUS" ]; then
        STATUS="unknown"
    fi
    STATE=$(systemctl show -p SubState --value "$SERVICE" 2>/dev/null)
    if [ -z "$STATE" ]; then
        STATE="unknown"
    fi

    if [ "$STATUS" != "active" ]; then
        OVERALL="degraded"
        if [ "$RESTART_FAILED" = "true" ]; then
            systemctl restart "$SERVICE" >/dev/null 2>&1
            STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "unknown")
            STATE=$(systemctl show -p SubState --value "$SERVICE" 2>/dev/null || echo "unknown")
        fi
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        SERVICES_JSON="$SERVICES_JSON,"
    fi

    SERVICES_JSON="$SERVICES_JSON \"$SERVICE\": { \"status\": \"$STATUS\", \"state\": \"$STATE\", \"type\": \"systemd\" }"
done

# Check Docker services
for SERVICE in $DOCKER_SERVICES; do
    # Check if container is running
    CONTAINER_STATUS=$(docker ps --filter "name=${SERVICE}" --format "{{.Status}}" 2>/dev/null)
    if [ -n "$CONTAINER_STATUS" ]; then
        STATUS="active"
        STATE="running"
    else
        # Check if container exists but is stopped
        CONTAINER_EXISTS=$(docker ps -a --filter "name=${SERVICE}" --format "{{.Status}}" 2>/dev/null)
        if [ -n "$CONTAINER_EXISTS" ]; then
            STATUS="inactive"
            STATE="stopped"
            OVERALL="degraded"
        else
            STATUS="unknown"
            STATE="not_found"
            OVERALL="degraded"
        fi
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        SERVICES_JSON="$SERVICES_JSON,"
    fi

    SERVICES_JSON="$SERVICES_JSON \"$SERVICE\": { \"status\": \"$STATUS\", \"state\": \"$STATE\", \"type\": \"docker\" }"
done

SERVICES_JSON="$SERVICES_JSON }"

JSON_REPORT=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "services": $SERVICES_JSON,
  "overall": "$OVERALL"
}
EOF
)

echo "$JSON_REPORT"

if [ -n "$SLACK_WEBHOOK_URL" ] && [ "$OVERALL" != "healthy" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"*Service Watchdog Alert* - Status: \`$OVERALL\`\n\`\`\`$JSON_REPORT\`\`\`\"}" \
        "$SLACK_WEBHOOK_URL" > /dev/null
fi
