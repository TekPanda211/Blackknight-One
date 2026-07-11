# Conditional Access Design

## Purpose

This document captures Conditional Access design principles for the Terraform Entra lab.

## Design Principles

Conditional Access policies should be designed around Zero Trust principles:

- Verify explicitly
- Use least privilege
- Assume breach
- Require strong authentication
- Minimize unnecessary exclusions
- Test changes in report-only mode before enforcement

## Recommended Policy Areas

### Require MFA for Administrators

Purpose:
Require strong authentication for privileged roles.

Key design points:

- Include privileged directory roles
- Require phishing-resistant MFA where possible
- Exclude only approved break-glass accounts
- Monitor sign-in logs after enforcement

### Require MFA for All Users

Purpose:
Protect standard user access to cloud applications.

Key design points:

- Include all users
- Exclude emergency access accounts
- Consider phased rollout by group
- Start in report-only mode

### Block Legacy Authentication

Purpose:
Prevent authentication protocols that do not support modern controls.

Key design points:

- Target legacy client apps
- Block access
- Monitor sign-in logs for impact

### Require Compliant or Hybrid Joined Device

Purpose:
Restrict sensitive application access to trusted devices.

Key design points:

- Target sensitive apps
- Require compliant device or hybrid joined device
- Validate Intune and device registration dependencies

### Risk-Based Access

Purpose:
Adjust authentication requirements based on detected risk.

Key design points:

- User risk and sign-in risk require appropriate licensing
- Require password change or MFA where supported
- Review risk events before enforcement

## Break-Glass Accounts

Emergency access accounts should be:

- Cloud-only
- Excluded from Conditional Access policies
- Protected with strong credentials
- Monitored closely
- Rarely used
- Reviewed regularly

## Validation Checks

- Are policies enabled or report-only?
- Are exclusions documented?
- Are emergency accounts monitored?
- Are privileged users protected?
- Are legacy protocols blocked?
- Are policies scoped correctly?

## Interview Talking Point

Conditional Access is not just a switch to turn on MFA. It is a policy framework that must balance security, usability, exclusions, application impact, device trust, and operational readiness.
