#!/bin/bash
set -euo pipefail

DASHBOARD_FILE="grafana/dashboards/cloudwatch-dashboard.json"
DASHBOARD_TITLE=$(python3 -c "import json; d=json.load(open('$DASHBOARD_FILE')); print(d.get('dashboard',{}).get('title','unknown'))")
DASHBOARD_UID=$(python3 -c "import json; d=json.load(open('$DASHBOARD_FILE')); print(d.get('dashboard',{}).get('uid','no-uid'))")
echo "======================================"
echo " Deploy Grafana Dashboard"
echo "======================================"
echo " Grafana URL : $GRAFANA_URL"
echo " Title       : $DASHBOARD_TITLE"
echo " UID         : $DASHBOARD_UID"
echo "======================================"
EXISTING_STATUS=$(curl -s -o /tmp/existing_dash.json -w "%{http_code}" \
  "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID" \
  -H "Authorization: Bearer $GRAFANA_API_KEY")
if [ "$EXISTING_STATUS" == "200" ]; then
  VER=$(python3 -c "import json; print(json.load(open('/tmp/existing_dash.json')).get('dashboard',{}).get('version',0))" 2>/dev/null || echo "0")
  echo "Dashboard exists at version $VER - will UPDATE"
else
  echo "Dashboard not found - will CREATE"
fi
HTTP_STATUS=$(curl -s -o /tmp/dash_resp.json -w "%{http_code}" \
  -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$DASHBOARD_FILE")
echo "Response: $(cat /tmp/dash_resp.json)"
if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  NEW_VER=$(python3 -c "import json; r=json.load(open('/tmp/dash_resp.json')); v=r.get('version',0); print('CREATED v1' if v==1 else 'UPDATED to version '+str(v))" 2>/dev/null || echo "deployed")
  DASH_URL=$(python3 -c "import json; print(json.load(open('/tmp/dash_resp.json')).get('url',''))" 2>/dev/null || echo "")
  echo "Dashboard $NEW_VER (HTTP $HTTP_STATUS)"
  if [ -n "$DASH_URL" ]; then echo "View at: $GRAFANA_URL$DASH_URL"; fi
else
  echo "ERROR: Dashboard deployment failed (HTTP $HTTP_STATUS)"
  exit 1
fi