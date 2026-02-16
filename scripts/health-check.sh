#!/bin/bash

APP_URL="${APP_URL:-https://app.aleqsys.com/health/}"
N8N_URL="${N8N_URL:-https://n8n.aleqsys.com/}"

check_endpoint() {
    local target_url=$1
    local curl_stats=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" "$target_url")
    local http_code=$(echo "$curl_stats" | cut -d: -f1)
    local duration_sec=$(echo "$curl_stats" | cut -d: -f2)
    local duration_ms=$(awk "BEGIN {print int($duration_sec * 1000)}")

    if [ "$target_url" == "https://app.aleqsys.com/health/" ] && ([ "$http_code" -lt 200 ] || [ "$http_code" -ge 400 ]); then
        target_url="https://app.aleqsys.com/"
        curl_stats=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" "$target_url")
        http_code=$(echo "$curl_stats" | cut -d: -f1)
        duration_sec=$(echo "$curl_stats" | cut -d: -f2)
        duration_ms=$(awk "BEGIN {print int($duration_sec * 1000)}")
    fi

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        echo "{\"status\": \"healthy\", \"response_time_ms\": $duration_ms}"
    else
        echo "{\"status\": \"unhealthy\", \"response_time_ms\": $duration_ms, \"http_code\": $http_code}"
    fi
}

APP_CHECK_RESULT=$(check_endpoint "$APP_URL")
N8N_CHECK_RESULT=$(check_endpoint "$N8N_URL")

APP_STATUS_ONLY=$(echo "$APP_CHECK_RESULT" | grep -o '"status": "[^"]*"' | head -1 | cut -d'"' -f4)
N8N_STATUS_ONLY=$(echo "$N8N_CHECK_RESULT" | grep -o '"status": "[^"]*"' | head -1 | cut -d'"' -f4)

OVERALL_HEALTH="healthy"
FINAL_EXIT_CODE=0

if [ "$APP_STATUS_ONLY" != "healthy" ] || [ "$N8N_STATUS_ONLY" != "healthy" ]; then
    OVERALL_HEALTH="unhealthy"
    FINAL_EXIT_CODE=1
fi

UTC_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat <<EOF
{
  "timestamp": "$UTC_TIMESTAMP",
  "checks": {
    "app": $APP_CHECK_RESULT,
    "n8n": $N8N_CHECK_RESULT
  },
  "overall": "$OVERALL_HEALTH"
}
EOF

exit $FINAL_EXIT_CODE
