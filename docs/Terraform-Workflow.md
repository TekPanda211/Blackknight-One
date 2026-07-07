# Terraform Workflow

## Purpose

This document defines the working Terraform process for the Entra IAM lab. The goal is to follow a repeatable engineering workflow that mirrors how Infrastructure as Code is commonly managed in cloud and identity engineering teams.

## Standard Workflow

```text
Write code
terraform fmt
terraform validate
terraform plan
terraform apply
Verify results
Commit changes
Push to GitHub
```

## Commands

### Format Terraform Files

```powershell
terraform fmt
```

### Validate Configuration

```powershell
terraform validate
```

### Preview Changes

```powershell
terraform plan
```

### Apply Changes

```powershell
terraform apply
```

### Destroy Lab Resources

```powershell
terraform destroy
```

## Git Workflow

### Check Current Changes

```powershell
git status
```

### Stage Changes

```powershell
git add .
```

### Commit Changes

```powershell
git commit -m "Describe the change"
```

### Push to GitHub

```powershell
git push
```

## Files That Should Not Be Committed

The following files are generated locally and should not be committed:

```text
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars
```

The `.terraform.lock.hcl` file should be committed because it locks provider versions for repeatability.

## Professional Practice

Each Terraform change should answer three questions:

1. What identity resource is being created or changed?
2. Why is the change needed?
3. How can the change be validated after deployment?
