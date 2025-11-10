# GitHub Actions Workflows

## Available Workflows

### 1. Terraform CI/CD
**File:** `terraform.yml`  
**Trigger:** Automatic on Terraform changes  
**Purpose:** Validates, plans, and applies Terraform infrastructure

### 2. Update Karpenter Values
**File:** `update-karpenter-values.yml`  
**Trigger:** 
- Automatic after Terraform CI/CD completes
- Manual via workflow_dispatch

**Purpose:** Updates Karpenter configuration from Terraform outputs

### 3. Terraform Destroy ⚠️
**File:** `terraform-destroy.yml`  
**Trigger:** Manual only  
**Purpose:** Destroys all infrastructure

**How to use:**
1. Go to: https://github.com/chiju/eks-lab-argocd/actions/workflows/terraform-destroy.yml
2. Click "Run workflow"
3. Type `destroy` to confirm
4. Click "Run workflow"

**Safety:** Requires typing "destroy" to prevent accidents
