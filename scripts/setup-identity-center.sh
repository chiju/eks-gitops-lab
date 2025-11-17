#!/bin/bash
set -e

AWS_PROFILE="oth_infra"
REGION="eu-central-1"

echo "🚀 Setting up AWS IAM Identity Center..."
echo "AWS Profile: $AWS_PROFILE"
echo "Region: $REGION"
echo ""

# Get user's email for the + trick
read -p "Enter your email (e.g., your-email@gmail.com): " USER_EMAIL

if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "❌ Invalid email format"
  exit 1
fi

echo ""
echo "📧 Will create users with + trick:"
echo "  - ${USER_EMAIL%@*}+alice@${USER_EMAIL#*@}"
echo "  - ${USER_EMAIL%@*}+bob@${USER_EMAIL#*@}"
echo "  - ${USER_EMAIL%@*}+charlie@${USER_EMAIL#*@}"
echo "  - ${USER_EMAIL%@*}+diana@${USER_EMAIL#*@}"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

# Check if Identity Center is already enabled
echo ""
echo "Checking IAM Identity Center status..."
INSTANCE_ARN=$(aws sso-admin list-instances \
  --region $REGION \
  --profile $AWS_PROFILE \
  --query 'Instances[0].InstanceArn' \
  --output text 2>/dev/null || echo "None")

if [ "$INSTANCE_ARN" == "None" ] || [ -z "$INSTANCE_ARN" ]; then
  echo "⚠️  IAM Identity Center is not enabled"
  echo ""
  echo "Please enable it manually (one-time setup):"
  echo "1. Go to: https://console.aws.amazon.com/singlesignon"
  echo "2. Click 'Enable'"
  echo "3. Choose 'Identity Center directory' as identity source"
  echo "4. Re-run this script"
  exit 1
fi

echo "✅ IAM Identity Center is enabled"
echo "Instance ARN: $INSTANCE_ARN"

# Get Identity Store ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances \
  --region $REGION \
  --profile $AWS_PROFILE \
  --query 'Instances[0].IdentityStoreId' \
  --output text)

echo "Identity Store ID: $IDENTITY_STORE_ID"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Create users
echo ""
echo "Creating users..."

declare -A USERS=(
  ["alice-admin"]="Alice Admin"
  ["bob-devops"]="Bob DevOps"
  ["charlie-dev"]="Charlie Developer"
  ["diana-viewer"]="Diana Viewer"
)

declare -A USER_IDS

for username in "${!USERS[@]}"; do
  display_name="${USERS[$username]}"
  email="${USER_EMAIL%@*}+${username%-*}@${USER_EMAIL#*@}"
  
  echo "  Creating user: $username ($email)"
  
  # Check if user exists
  EXISTING_USER=$(aws identitystore list-users \
    --identity-store-id $IDENTITY_STORE_ID \
    --region $REGION \
    --profile $AWS_PROFILE \
    --filters AttributePath=UserName,AttributeValue=$username \
    --query 'Users[0].UserId' \
    --output text 2>/dev/null || echo "None")
  
  if [ "$EXISTING_USER" != "None" ] && [ -n "$EXISTING_USER" ]; then
    echo "    ✅ User already exists"
    USER_IDS[$username]=$EXISTING_USER
  else
    USER_ID=$(aws identitystore create-user \
      --identity-store-id $IDENTITY_STORE_ID \
      --region $REGION \
      --profile $AWS_PROFILE \
      --user-name $username \
      --display-name "$display_name" \
      --name FamilyName="${display_name##* }",GivenName="${display_name%% *}" \
      --emails Value=$email,Type=work,Primary=true \
      --query 'UserId' \
      --output text)
    
    USER_IDS[$username]=$USER_ID
    echo "    ✅ Created (ID: $USER_ID)"
  fi
done

# Create Permission Sets
echo ""
echo "Creating permission sets..."

declare -A PERMISSION_SETS=(
  ["PlatformAdmin"]="arn:aws:iam::aws:policy/AdministratorAccess"
  ["DevOpsEngineer"]="arn:aws:iam::aws:policy/PowerUserAccess"
  ["Developer"]="arn:aws:iam::aws:policy/ReadOnlyAccess"
  ["ReadOnly"]="arn:aws:iam::aws:policy/ViewOnlyAccess"
)

declare -A PERMISSION_SET_ARNS

for ps_name in "${!PERMISSION_SETS[@]}"; do
  policy_arn="${PERMISSION_SETS[$ps_name]}"
  
  echo "  Creating permission set: $ps_name"
  
  # Check if permission set exists
  EXISTING_PS=$(aws sso-admin list-permission-sets \
    --instance-arn $INSTANCE_ARN \
    --region $REGION \
    --profile $AWS_PROFILE \
    --query "PermissionSets[?contains(@, '$ps_name')]" \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$EXISTING_PS" ]; then
    echo "    ✅ Permission set already exists"
    PERMISSION_SET_ARNS[$ps_name]=$EXISTING_PS
  else
    PS_ARN=$(aws sso-admin create-permission-set \
      --instance-arn $INSTANCE_ARN \
      --region $REGION \
      --profile $AWS_PROFILE \
      --name $ps_name \
      --description "Permission set for $ps_name" \
      --session-duration PT4H \
      --query 'PermissionSet.PermissionSetArn' \
      --output text)
    
    # Attach managed policy
    aws sso-admin attach-managed-policy-to-permission-set \
      --instance-arn $INSTANCE_ARN \
      --region $REGION \
      --profile $AWS_PROFILE \
      --permission-set-arn $PS_ARN \
      --managed-policy-arn $policy_arn
    
    # Provision permission set
    aws sso-admin provision-permission-set \
      --instance-arn $INSTANCE_ARN \
      --region $REGION \
      --profile $AWS_PROFILE \
      --permission-set-arn $PS_ARN \
      --target-type AWS_ACCOUNT \
      --target-id $ACCOUNT_ID
    
    PERMISSION_SET_ARNS[$ps_name]=$PS_ARN
    echo "    ✅ Created and provisioned"
  fi
done

# Assign users to permission sets
echo ""
echo "Assigning users to permission sets..."

declare -A ASSIGNMENTS=(
  ["alice-admin"]="PlatformAdmin"
  ["bob-devops"]="DevOpsEngineer"
  ["charlie-dev"]="Developer"
  ["diana-viewer"]="ReadOnly"
)

for username in "${!ASSIGNMENTS[@]}"; do
  ps_name="${ASSIGNMENTS[$username]}"
  user_id="${USER_IDS[$username]}"
  ps_arn="${PERMISSION_SET_ARNS[$ps_name]}"
  
  echo "  Assigning $username → $ps_name"
  
  aws sso-admin create-account-assignment \
    --instance-arn $INSTANCE_ARN \
    --region $REGION \
    --profile $AWS_PROFILE \
    --target-type AWS_ACCOUNT \
    --target-id $ACCOUNT_ID \
    --permission-set-arn $ps_arn \
    --principal-type USER \
    --principal-id $user_id \
    2>/dev/null || echo "    ⚠️  Assignment may already exist"
  
  echo "    ✅ Assigned"
done

# Get SSO start URL
SSO_START_URL="https://d-$(echo $INSTANCE_ARN | cut -d'/' -f2).awsapps.com/start"

echo ""
echo "✅ IAM Identity Center setup complete!"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📧 Check your email ($USER_EMAIL) for verification links"
echo "   You'll receive 4 emails (one for each user)"
echo ""
echo "🔗 SSO Start URL: $SSO_START_URL"
echo ""
echo "📝 Next steps:"
echo ""
echo "1. Verify all 4 email addresses"
echo ""
echo "2. Test SSO login:"
echo "   aws configure sso"
echo "   SSO start URL: $SSO_START_URL"
echo "   SSO region: $REGION"
echo ""
echo "3. Continue with Terraform deployment"
echo ""
