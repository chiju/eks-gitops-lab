# Local Setup Files

This folder contains configuration files for local development.

## For Local Development

1. **Copy providers file:**
```bash
cp local_setup/providers-local.tf terraform/providers.tf
```

2. **Initialize with local backend:**
```bash
cd terraform
terraform init -backend-config=../local_setup/backend-local.hcl
```

3. **Run terraform:**
```bash
terraform plan
terraform apply
```

## For GitHub Actions

GitHub Actions uses the default files (no changes needed):
- `terraform/providers.tf` - Uses OIDC (no profile)
- `terraform/backend.tf` - Uses OIDC (no profile)

## Files
- `backend-local.hcl`: Backend config with AWS profile
- `providers-local.tf`: Providers config with AWS profile
