#!/bin/bash
set -euo pipefail

GRAFANA_URL=$(aws cloudformation list-exports \
  --region "$AWS_REGION" \
  --query "Exports[?Name=='grafana-workspace-url'].Value" \
  --output text)

WORKSPACE_ID=$(aws cloudformation list-exports \
  --region "$AWS_REGION" \
  --query "Exports[?Name=='grafana-workspace-id'].Value" \
  --output text)

GRAFANA_ROLE_ARN=$(aws cloudformation list-exports \
  --region "$AWS_REGION" \
  --query "Exports[?Name=='grafana-role-arn'].Value" \
  --output text)

SNS_ARN=$(aws cloudformation list-exports \
  --region "$AWS_REGION" \
  --query "Exports[?Name=='GrafanaAlertTopicArn'].Value" \
  --output text)

if [ -z "$GRAFANA_URL" ] || [ "$GRAFANA_URL" == "None" ]; then
  echo "ERROR: grafana-workspace-url export not found"
  exit 1
fi

echo "Grafana URL      : $GRAFANA_URL"
echo "Workspace ID     : $WORKSPACE_ID"
echo "Grafana Role ARN : $GRAFANA_ROLE_ARN"
echo "SNS ARN          : $SNS_ARN"

KEY_NAME="github-actions-${GITHUB_RUN_ID}"
echo "Creating API key : $KEY_NAME"

GRAFANA_API_KEY=$(aws grafana create-workspace-api-key \
  --workspace-id "$WORKSPACE_ID" \
  --key-name "$KEY_NAME" \
  --key-role "ADMIN" \
  --seconds-to-live 3600 \
  --region "$AWS_REGION" \
  --query "key" --output text)

echo "API key created  : $KEY_NAME (TTL: 1 hour)"

echo "GRAFANA_URL=$GRAFANA_URL"           >> "$GITHUB_ENV"
echo "WORKSPACE_ID=$WORKSPACE_ID"         >> "$GITHUB_ENV"
echo "GRAFANA_ROLE_ARN=$GRAFANA_ROLE_ARN" >> "$GITHUB_ENV"
echo "SNS_ARN=$SNS_ARN"                   >> "$GITHUB_ENV"
echo "KEY_NAME=$KEY_NAME"                 >> "$GITHUB_ENV"
echo "::add-mask::$GRAFANA_API_KEY"
echo "GRAFANA_API_KEY=$GRAFANA_API_KEY"   >> "$GITHUB_ENV"