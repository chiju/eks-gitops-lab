# GitHub Actions CI/CD Setup

## Overview

Automated CI/CD pipeline for Terraform and Helm charts with security scanning and PR automation.

## Workflows

### 1. Terraform CI/CD (`.github/workflows/terraform.yml`)

**Triggers:**
- Pull requests to `main` or `bootstrap`
- Push to `main` or `bootstrap`
- Manual workflow dispatch

**Jobs:**

#### Validate
- ✅ Terraform format check
- ✅ Terraform init (no backend)
- ✅ Terraform validate

#### Security
- ✅ Checkov security scan
- ✅ Detects misconfigurations
- ✅ Soft fail (doesn't block)

#### Plan (PR only)
- ✅ Terraform plan
- ✅ Posts plan to PR comment
- ✅ Requires AWS credentials

#### Apply (main branch only)
- ✅ Terraform apply
- ✅ Requires manual approval (production environment)
- ✅ Only on push to main

### 2. Helm Charts CI (`.github/workflows/helm.yml`)

**Triggers:**
- Changes to `apps/` or `argocd-apps/`

**Jobs:**
- ✅ Helm lint all charts
- ✅ Helm template validation
- ✅ YAML validation for ArgoCD apps

## Setup Instructions

### 1. AWS OIDC Provider (Recommended)

Create OIDC provider for GitHub Actions:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::432801802107:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:chiju/eks-lab-argocd:*"
        }
      }
    }
  ]
}
```

Attach policies:
- `AdministratorAccess` (for learning)
- Or custom policy with EKS, VPC, IAM permissions

### 3. Add GitHub Secrets

Go to: **Settings → Secrets and variables → Actions**

Add:
```
AWS_ROLE_ARN = arn:aws:iam::432801802107:role/GitHubActionsRole
```

**Note:** `GITHUB_TOKEN` is automatically provided by GitHub Actions for ArgoCD repo access.

### 4. Create Production Environment

Go to: **Settings → Environments → New environment**

Name: `production`

Protection rules:
- ✅ Required reviewers (add yourself)
- ✅ Wait timer: 0 minutes

### 5. Enable Workflows

Push to trigger:
```bash
git add .github/
git commit -m "Add GitHub Actions workflows"
git push
```

## Local Pre-commit Hooks

Install pre-commit:
```bash
pip install pre-commit
pre-commit install
```

Run manually:
```bash
pre-commit run --all-files
```

## Workflow Behavior

### Pull Request Flow
```
1. Developer creates PR
2. Validate job runs (format, validate)
3. Security job runs (Checkov scan)
4. Plan job runs (posts plan to PR)
5. Reviewer approves
6. Merge to main
7. Apply job runs (requires approval)
8. Infrastructure deployed
```

### Direct Push to Main
```
1. Push to main
2. Validate + Security jobs run
3. Apply job waits for approval
4. Approve in GitHub UI
5. Infrastructure deployed
```

## Best Practices Implemented

✅ **Security:**
- OIDC instead of long-lived credentials
- Checkov security scanning
- Manual approval for production

✅ **Automation:**
- Auto-format check
- Auto-validate
- PR comments with plan

✅ **Safety:**
- Plan before apply
- Environment protection
- Soft fail on security issues

✅ **Visibility:**
- PR comments with plan
- Job summaries
- Clear workflow names

## Troubleshooting

### "Error: No valid credential sources"
- Check AWS_ROLE_ARN secret exists
- Verify OIDC provider is created
- Check IAM role trust policy

### "Terraform format check failed"
```bash
cd terraform
terraform fmt -recursive
git add .
git commit -m "Format Terraform code"
```

### "Checkov failed"
- Review security findings
- Add exceptions if needed
- Workflow continues (soft fail)

## Cost Considerations

GitHub Actions free tier:
- 2,000 minutes/month for private repos
- Unlimited for public repos

Each workflow run: ~5-10 minutes
- Validate: 2 min
- Security: 2 min
- Plan: 3 min
- Apply: 15 min

## Next Steps

- [ ] Add Slack notifications
- [ ] Add cost estimation (Infracost)
- [ ] Add drift detection (scheduled)
- [ ] Add automated testing
