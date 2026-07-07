# Security Checks

## Purpose

This document lists security checks that can be used to validate an Entra ID environment after Terraform deployment.

## Group Security Checks

- Groups have clear naming standards
- Groups have owners
- Privileged groups are documented
- Empty groups are reviewed
- Stale groups are removed or justified
- Group membership aligns with least privilege
- Role-assignable groups are limited and reviewed

## Conditional Access Checks

- Policies are not unintentionally disabled
- Report-only policies are reviewed before enforcement
- Break-glass accounts are excluded and monitored
- Legacy authentication is blocked
- Privileged users require strong authentication
- Sensitive apps require appropriate controls
- Exclusions are documented and approved

## Access Package Checks

- Packages have owners
- Packages have assignment policies
- Sensitive packages require approval
- Temporary access expires
- Access reviews are configured where needed
- External user access is intentionally scoped

## Role Assignment Checks

- Global Administrator assignments are minimized
- Privileged roles are assigned only when required
- Permanent assignments are reviewed
- Eligible assignments are preferred where possible
- Role assignments are documented

## Enterprise Application Checks

- Applications have owners
- App assignments are scoped
- API permissions are reviewed
- Admin consent grants are documented
- Unused applications are reviewed
- Service principals are not over-permissioned

## Audit Data Sources

Potential data sources for validation:

- Microsoft Graph PowerShell
- Azure CLI
- Entra admin center exports
- Sign-in logs
- Audit logs
- Unified Audit Log
- Terraform state for deployed resources

## Future Automation Ideas

- Export groups and owners to CSV
- Export Conditional Access policy settings
- Export privileged role assignments
- Compare current groups against Terraform naming standards
- Identify access packages without expiration
- Identify applications without owners
- Create GitHub Actions to run terraform validate automatically
