#!/bin/bash
set -euo pipefail

EXISTING_DS=$(curl -s "$GRAFANA_URL/api/datasources" \
  -H "Authorization: Bearer $GRAFANA_API_KEY")

DS_EXISTS=$(echo "$EXISTING_DS" | python3 -c "
import sys, json
try:
    ds_list = json.load(sys.stdin)
    exists = any(
        ds.get('type') == 'cloudwatch' and ds.get('name') == 'CloudWatch'
        for ds in ds_list
    )
    print('true' if exists else 'false')
except:
    print('false')
")

if [ "$DS_EXISTS" == "true" ]; then
  echo "CloudWatch datasource already exists — skipping"
  exit 0
fi

echo "Creating CloudWatch datasource..."

HTTP_STATUS=$(curl -s -o /tmp/ds_resp.json -w "%{http_code}" \
  -X POST "$GRAFANA_URL/api/datasources" \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name":      "CloudWatch",
    "type":      "cloudwatch",
    "access":    "proxy",
    "isDefault": true,
    "jsonData": {
      "authType":      "default",
      "defaultRegion": "us-east-1",
      "logsTimeout":   "30s",
      "queryTimeout":  "60s"
    }
  }')

echo "Response: $(cat /tmp/ds_resp.json)"

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  DS_UID=$(cat /tmp/ds_resp.json | python3 -c "
import sys, json
print(json.load(sys.stdin).get('datasource', {}).get('uid', 'n/a'))
" 2>/dev/null || echo "n/a")
  echo "CloudWatch datasource CREATED (HTTP $HTTP_STATUS) | UID: $DS_UID"
else
  echo "ERROR: Datasource creation failed (HTTP $HTTP_STATUS)"
  exit 1
fi