# IAM Audit Strategy

## Purpose

This document describes how the Terraform Entra lab will support identity security checks, audit readiness, and drift detection.

## Goal

The goal is not only to deploy IAM resources, but to inspect and validate them after deployment. Terraform creates the intended state, while Microsoft Graph and PowerShell can be used to pull current configuration data for review.

## Audit Areas

### Group Management

Security checks should review:

- Group naming standards
- Group type
- Security-enabled status
- Group owners
- Group members
- Stale or empty groups
- Overly broad access groups
- Groups used for privileged access

### Conditional Access

Security checks should review:

- Policy state: enabled, disabled, or report-only
- Included users and groups
- Excluded users and groups
- Cloud apps included
- Grant controls
- Session controls
- MFA requirements
- Break-glass account exclusions
- Risk-based policy configuration

### Access Packages

Security checks should review:

- Catalog ownership
- Access package ownership
- Assignment policies
- Approval requirements
- Expiration settings
- Access review settings
- External user controls
- Resources included in each package

### Role Assignments

Security checks should review:

- Privileged role assignments
- Eligible versus active assignments
- Permanent privileged access
- Role-assignable groups
- Least-privilege alignment
- Unused or stale privileged access

### Enterprise Applications

Security checks should review:

- App owners
- Assigned users and groups
- Consent grants
- API permissions
- Service principals
- Sign-in activity
- Risky or unused applications

## Validation Approach

```text
Terraform desired state
        ↓
Microsoft Graph / PowerShell data pull
        ↓
Compare against expected standard
        ↓
Document findings
        ↓
Remediate with Terraform or approved process
```

## Example Security Questions

- Are any groups missing owners?
- Are any access packages missing expiration?
- Are Conditional Access policies still in report-only mode?
- Are any privileged roles permanently assigned?
- Are any enterprise applications over-permissioned?
- Are group memberships aligned to least privilege?

## Long-Term Goal

Build repeatable IAM audit checks that can be run before reviews, during access audits, or after Terraform changes to confirm the environment remains aligned with security standards.
