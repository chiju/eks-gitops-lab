# Integration Steps - IAM Identity Center (Real SSO!)

## What Was Created

✅ **Bootstrap Script**: `scripts/setup-identity-center.sh`  
✅ **Terraform Module**: `terraform/modules/iam-identity-center/`  
✅ **ArgoCD App**: `apps/rbac-setup/`  
✅ **ArgoCD Manifest**: `argocd-apps/rbac-setup.yaml`  

---

## Complete Setup Flow

### **Step 1: Bootstrap S3 Backend** (if not done)
```bash
./scripts/bootstrap-backend.sh
```

### **Step 2: Setup OIDC** (if not done)
```bash
./scripts/setup-oidc-access.sh
gh secret set GIT_USERNAME -b "your-github-username"
gh secret set ARGOCD_GITHUB_TOKEN -b "your-github-pat"
```

### **Step 3: Enable IAM Identity Center** (Manual - One Time)
```
1. Go to: https://console.aws.amazon.com/singlesignon
2. Click "Enable"
3. Choose "Identity Center directory" as identity source
```

### **Step 4: Run Identity Center Setup**
```bash
./scripts/setup-identity-center.sh
# Enter your email when prompted
# Uses + trick: your-email+alice@gmail.com
```

**This creates:**
- ✅ 4 users (alice, bob, charlie, diana)
- ✅ 4 permission sets (PlatformAdmin, DevOpsEngineer, Developer, ReadOnly)
- ✅ User assignments

### **Step 5: Verify Emails**
Check your inbox for 4 verification emails and click the links.

### **Step 6: Add Module to Terraform**

Edit `terraform/main.tf`:
```hcl
# IAM Identity Center Integration
module "iam_identity_center" {
  source = "./modules/iam-identity-center"
  
  cluster_name = var.cluster_name
  
  depends_on = [module.eks]
}
```

Edit `terraform/outputs.tf`:
```hcl
# IAM Identity Center
output "identity_center_setup" {
  value = module.iam_identity_center.setup_complete
}
```

### **Step 7: Deploy**
```bash
git add .
git commit -m "feat: Add IAM Identity Center with RBAC"
git push origin feature/iam-identity-center-simulation
```

**GitHub Actions will:**
- ✅ Create EKS Access Entries for SSO roles
- ✅ ArgoCD deploys RBAC automatically

---

## Step 8: Test SSO Access

### **Configure SSO**
```bash
aws configure sso
# SSO start URL: (from setup script output)
# SSO region: eu-central-1
# Account: (your account)
# Role: PlatformAdmin
# Profile name: alice-admin
```

### **Login**
```bash
aws sso login --profile alice-admin
```

**Opens browser → Login with email → Done!**

### **Access EKS**
```bash
aws eks update-kubeconfig --name eks-lab --profile alice-admin --region eu-central-1
kubectl get nodes
```

### **Test Other Users**
```bash
# Bob (DevOps)
aws configure sso  # Choose DevOpsEngineer
aws sso login --profile bob-devops
aws eks update-kubeconfig --name eks-lab --profile bob-devops --region eu-central-1 --alias eks-lab-devops
kubectl get pods -A

# Charlie (Developer)
aws configure sso  # Choose Developer
aws sso login --profile charlie-dev
aws eks update-kubeconfig --name eks-lab --profile charlie-dev --region eu-central-1 --alias eks-lab-dev
kubectl get pods -n dev
kubectl get nodes  # Should fail (RBAC working!)
```

---

## What's Different from IAM Users?

### ✅ **Better:**
- Browser-based login (no access keys!)
- Temporary credentials (auto-expire)
- Real SSO experience
- Industry standard approach

### ⚠️ **Same:**
- EKS Access Entries (identical)
- Kubernetes RBAC (identical)
- Namespace isolation (identical)

---

## Security for Public Repo

✅ **Safe in Git:**
- Bootstrap script (no emails)
- Terraform module (no credentials)
- RBAC manifests

❌ **NOT in Git:**
- User emails (added via script)
- SSO start URL (has account ID)
- Credentials (temporary, never stored)

---

## Cleanup

```bash
# Remove module from main.tf
git commit -m "chore: Remove Identity Center integration"
git push

# Delete users (optional)
# Via AWS Console → IAM Identity Center → Users
```

---

## Summary

**What You Get:**
- ✅ Real AWS SSO experience
- ✅ Browser-based authentication
- ✅ No long-lived credentials
- ✅ Production-ready setup
- ✅ FREE (no cost)

**Perfect for learning the real thing!** 🎓

