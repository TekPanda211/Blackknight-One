# Terraform Entra Lab

Infrastructure as Code lab focused on Microsoft Entra ID, IAM engineering, security validation, and audit readiness.

## Purpose

This project is designed to build practical experience with Terraform, Microsoft Entra ID, Microsoft Graph, Azure CLI, PowerShell, Git, and GitHub workflows. The goal is not only to create IAM resources as code, but also to validate identity configuration for security checks, least-privilege review, audit readiness, and drift detection.

## Core Focus Areas

- Create and manage Microsoft Entra ID groups with Terraform
- Model IAM resources using Infrastructure as Code
- Document Conditional Access design and security intent
- Document Access Package and Identity Governance architecture
- Pull identity configuration data using Microsoft Graph and PowerShell
- Validate group membership, role assignments, and access controls
- Support audit readiness through repeatable security checks
- Compare deployed configuration against least-privilege standards

## Current Tooling

- Terraform
- Azure CLI
- Git
- GitHub
- Microsoft Entra ID
- Microsoft Graph PowerShell
- Visual Studio Code

## Planned Repository Structure

```text
terraform-entra-lab/
├── README.md
├── docs/
│   ├── Terraform-Workflow.md
│   ├── IAM-Audit-Strategy.md
│   ├── Conditional-Access-Design.md
│   ├── Access-Packages-Design.md
│   └── Security-Checks.md
├── 01-foundations/
├── 02-groups/
├── 03-conditional-access/
├── 04-access-packages/
├── 05-audit-checks/
└── 06-github-actions/
```

## Engineering Goal

This lab is intended to demonstrate a practical IAM engineering workflow:

```text
Design IAM Standard
        ↓
Create Terraform Code
        ↓
Run terraform fmt / validate / plan
        ↓
Apply in lab tenant
        ↓
Pull configuration data with Graph / PowerShell
        ↓
Validate against least-privilege and audit standards
        ↓
Document findings and improve design
```
