#!/bin/bash
set -e

# Usage: ./setup-identity-center.sh [email@example.com]

AWS_PROFILE="oth_infra"
REGION="eu-central-1"

echo "🚀 Setting up AWS IAM Identity Center..."
echo "AWS Profile: $AWS_PROFILE"
echo "Region: $REGION"
echo ""

# Check if Identity Center is enabled
echo "Checking if Identity Center is enabled..."
INSTANCE_ARN=$(aws sso-admin list-instances --profile $AWS_PROFILE --region $REGION --query 'Instances[0].InstanceArn' --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_ARN" ] || [ "$INSTANCE_ARN" = "None" ]; then
  echo "❌ IAM Identity Center is not enabled"
  echo ""
  echo "Please enable it first (one-time, takes 30 seconds):"
  echo "1. Go to: https://console.aws.amazon.com/singlesignon"
  echo "2. Click 'Enable'"
  echo "3. Choose 'Identity Center directory' as identity source"
  echo ""
  echo "Then run this script again."
  exit 1
fi

echo "✅ Identity Center is enabled"
echo "Instance ARN: $INSTANCE_ARN"
echo ""

# Get Identity Store ID and Account ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances --profile $AWS_PROFILE --region $REGION --query 'Instances[0].IdentityStoreId' --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)

# Get user's email
USER_EMAIL="$1"
if [ -z "$USER_EMAIL" ]; then
  read -p "Enter your email (e.g., your-email@gmail.com): " USER_EMAIL
fi

if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "❌ Invalid email format"
  exit 1
fi

echo "📧 Will create users with + trick:"
echo "  - ${USER_EMAIL%@*}+alice@${USER_EMAIL#*@}"
echo "  - ${USER_EMAIL%@*}+bob@${USER_EMAIL#*@}"
echo "  - ${USER_EMAIL%@*}+charlie@${USER_EMAIL#*@}"
echo "  - ${USER_EMAIL%@*}+diana@${USER_EMAIL#*@}"
echo ""

# Create users
echo "Creating users..."

create_user() {
  local username=$1
  local display_name=$2
  local email="${USER_EMAIL%@*}+${username%-*}@${USER_EMAIL#*@}"
  
  echo "  $username ($email)"
  aws identitystore create-user \
    --identity-store-id $IDENTITY_STORE_ID \
    --region $REGION \
    --profile $AWS_PROFILE \
    --user-name $username \
    --display-name "$display_name" \
    --name FamilyName="${display_name##* }",GivenName="${display_name%% *}" \
    --emails Value=$email,Type=work,Primary=true \
    --query 'UserId' \
    --output text
}

USER_ID_ALICE=$(create_user "alice-admin" "Alice Admin")
USER_ID_BOB=$(create_user "bob-devops" "Bob DevOps")
USER_ID_CHARLIE=$(create_user "charlie-dev" "Charlie Developer")
USER_ID_DIANA=$(create_user "diana-viewer" "Diana Viewer")

echo "✅ Users created"
echo ""

# Create permission sets
echo "Creating permission sets..."

create_permission_set() {
  local name=$1
  local policy=$2
  
  echo "  $name"
  PS_ARN=$(aws sso-admin create-permission-set \
    --instance-arn $INSTANCE_ARN \
    --region $REGION \
    --profile $AWS_PROFILE \
    --name $name \
    --description "Permission set for $name" \
    --session-duration PT4H \
    --query 'PermissionSet.PermissionSetArn' \
    --output text)
  
  aws sso-admin attach-managed-policy-to-permission-set \
    --instance-arn $INSTANCE_ARN \
    --region $REGION \
    --profile $AWS_PROFILE \
    --permission-set-arn $PS_ARN \
    --managed-policy-arn $policy > /dev/null
  
  echo "$PS_ARN"
}

PS_ARN_ADMIN=$(create_permission_set "PlatformAdmin" "arn:aws:iam::aws:policy/AdministratorAccess")
PS_ARN_DEVOPS=$(create_permission_set "DevOpsEngineer" "arn:aws:iam::aws:policy/PowerUserAccess")
PS_ARN_DEV=$(create_permission_set "Developer" "arn:aws:iam::aws:policy/ReadOnlyAccess")
PS_ARN_VIEWER=$(create_permission_set "ReadOnly" "arn:aws:iam::aws:policy/ReadOnlyAccess")

echo "✅ Permission sets created"
echo ""

# Assign users to permission sets
echo "Assigning users to permission sets..."

assign_user() {
  local user_id=$1
  local ps_arn=$2
  local name=$3
  
  echo "  $name"
  aws sso-admin create-account-assignment \
    --instance-arn $INSTANCE_ARN \
    --region $REGION \
    --profile $AWS_PROFILE \
    --target-type AWS_ACCOUNT \
    --target-id $ACCOUNT_ID \
    --permission-set-arn $ps_arn \
    --principal-type USER \
    --principal-id $user_id > /dev/null 2>&1 || echo "    (may already exist)"
}

assign_user "$USER_ID_ALICE" "$PS_ARN_ADMIN" "alice-admin → PlatformAdmin"
assign_user "$USER_ID_BOB" "$PS_ARN_DEVOPS" "bob-devops → DevOpsEngineer"
assign_user "$USER_ID_CHARLIE" "$PS_ARN_DEV" "charlie-dev → Developer"
assign_user "$USER_ID_DIANA" "$PS_ARN_VIEWER" "diana-viewer → ReadOnly"

echo "✅ Assignments complete"
echo ""

# Get SSO start URL
SSO_START_URL=$(aws sso-admin list-instances --profile $AWS_PROFILE --region $REGION --query 'Instances[0].IdentityStoreId' --output text | sed 's/^/https:\/\//' | sed 's/$/.awsapps.com\/start/')

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          ✅ IAM Identity Center Setup Complete!              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📧 Check your inbox for 4 verification emails and click the links"
echo ""
echo "🔐 SSO Start URL: https://d-99675f4fc7.awsapps.com/start"
echo ""
echo "Next steps:"
echo "1. Verify all 4 emails"
echo "2. Add Terraform module to main.tf"
echo "3. git push to deploy"
echo ""
