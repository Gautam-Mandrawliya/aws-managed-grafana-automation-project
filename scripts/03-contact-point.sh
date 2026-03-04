#!/bin/bash
set -euo pipefail

EXISTING_CPS=$(curl -s "$GRAFANA_URL/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer $GRAFANA_API_KEY")

CP_EXISTS=$(echo "$EXISTING_CPS" | python3 -c "
import sys, json
try:
    cps = json.load(sys.stdin)
    exists = any(cp.get('name') == 'ec2-cpu-alerts' for cp in cps)
    print('true' if exists else 'false')
except:
    print('false')
")

if [ "$CP_EXISTS" == "true" ]; then
  echo "Contact point 'ec2-cpu-alerts' already exists — skipping"
  exit 0
fi

echo "Creating SNS contact point..."

HTTP_STATUS=$(curl -s -o /tmp/cp_resp.json -w "%{http_code}" \
  -X POST "$GRAFANA_URL/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"ec2-cpu-alerts\",
    \"type\": \"sns\",
    \"settings\": {
      \"authProvider\":  \"arn\",
      \"arnFromAssume\": \"$GRAFANA_ROLE_ARN\",
      \"topic\":         \"$SNS_ARN\",
      \"subject\":       \"[Grafana] EC2 CPU Alert\"
    },
    \"disableResolveMessage\": false
  }")

echo "Response: $(cat /tmp/cp_resp.json)"

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "Contact point 'ec2-cpu-alerts' CREATED (HTTP $HTTP_STATUS)"
  echo "Alert route: Grafana → ec2-cpu-alerts → SNS → email"
else
  echo "ERROR: Contact point creation failed (HTTP $HTTP_STATUS)"
  exit 1
fi