<p align="center">
  <img src="docs/images/blackknight-one-hero.png" alt="BLACKKNIGHT ONE" width="900">
</p>

# BlackKnight One

Infrastructure Assessment Platform for Terraform, Microsoft Graph, Identity, and Security

---

## Overview

BlackKnight One is an enterprise PowerShell platform designed to assess, analyze, and validate modern cloud infrastructure.

The platform combines Terraform engineering, Microsoft Graph discovery, identity analysis, and security assessments into a single dashboard-driven experience with standardized reporting and executive scoring.

---

## Platform Capabilities

### Terraform

- Complete Infrastructure Assessment
- HCL Discovery Engine v2
- Security Analysis
- Configuration Validation
- Execution Plan Analysis
- Two-Phase Drift Detection
- Architecture Scoring
- Dependency Mapping
- Executive Reporting

### Microsoft Graph

- Tenant Discovery
- Graph Assessment
- Identity Inventory
- User Discovery
- Group Discovery
- Device Discovery
- Service Principal Discovery
- License Discovery

### Reporting

- Executive Assessment Reports
- JSON Export
- Confidence Scoring
- Security Findings
- Architecture Findings
- Release Recommendations

---

# Installation

```powershell
Import-Module .\scripts\PowerShell\Platform\Blackknight-Platform.psm1
```

---

# Quick Start

Launch the platform dashboard.

```powershell
Show-BKDashboard
```

The dashboard provides access to all assessment engines without requiring users to memorize PowerShell commands.

---

# Dashboard

```
============================================================
                  BLACKKNIGHT ONE
============================================================

Terraform
------------------------------------------------------------
1. Complete Terraform Assessment
2. Terraform HCL Discovery
3. Terraform Security Analysis
4. Terraform Drift Detection
5. Terraform Plan Analysis

Microsoft Graph
------------------------------------------------------------
6. Tenant Discovery
7. Graph Assessment
8. Identity Assessment

Platform
------------------------------------------------------------
9. Reports
10. Settings
11. About
12. Exit
```

---

# Terraform Assessment

The Terraform Assessment Engine combines multiple analysis engines into a single assessment.

Assessment workflow

```
Inventory

↓

HCL Discovery

↓

Security Analysis

↓

Configuration Validation

↓

Execution Plan Analysis

↓

Two-Phase Drift Confirmation

↓

Executive Assessment
```

Assessment output includes:

- Infrastructure Inventory
- Architecture Score
- Security Score
- Configuration Health
- Drift Analysis
- Executive Findings
- Release Recommendation

---

# HCL Discovery Engine

The HCL Discovery Engine performs deep parsing of Terraform configurations.

Collected information includes:

- Providers
- Required Providers
- Resources
- Data Sources
- Variables
- Outputs
- Modules
- Local Values
- Backend Configuration
- Imports
- Moved Blocks
- Dependencies
- Terraform Graph
- Version Constraints

---

# Terraform Security Analyzer

The Security Analyzer evaluates Terraform configurations for security risks and infrastructure best practices.

Current analysis includes:

- Backend Configuration
- State Storage
- Sensitive Variables
- Sensitive Outputs
- Provider Configuration
- Security Findings
- Executive Recommendations

Output includes:

- Security Score
- Security Health
- Security Findings
- Executive Recommendation

---

# Microsoft Graph Platform

The Microsoft Graph platform performs live tenant assessments.

Current capabilities include:

- Tenant Discovery
- Organization Inventory
- Domain Inventory
- User Inventory
- Group Inventory
- Device Inventory
- Service Principal Inventory
- License Inventory

Assessment output includes:

- Dataset Coverage
- Permission Coverage
- Inventory Coverage
- Executive Findings
- Assessment Confidence

---

# Project Structure

```
BlackKnight-One
│
├── docs
├── reports
├── scripts
│   └── PowerShell
│       ├── Platform
│       ├── Terraform
│       ├── Graph
│       ├── Identity
│       └── Reporting
│
├── tests
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

# Current Components

| Component | Status |
|-----------|--------|
| Dashboard | Complete |
| Terraform Assessment | Complete |
| HCL Discovery Engine v2 | Complete |
| Terraform Security Analyzer | Complete |
| Terraform Plan Analysis | Complete |
| Terraform Drift Detection | Complete |
| Microsoft Graph Discovery | Complete |
| Microsoft Graph Assessment | Complete |
| JSON Reporting | Complete |

---

# Roadmap

## Version 0.7.x

- Identity Assessment Engine
- Conditional Access Assessment
- Privileged Identity Assessment
- Application Permission Assessment
- Unified Executive Dashboard
- HTML Reporting

## Future Releases

- Exchange Online Assessment
- SharePoint Assessment
- Intune Assessment
- Azure Subscription Assessment
- Microsoft Defender Assessment
- Microsoft 365 Security Assessment

---

# Requirements

- PowerShell 7.4 or later
- Terraform CLI
- Microsoft Graph PowerShell SDK

---

# Contributing

Contributions, feature requests, bug reports, and pull requests are welcome.

---

# License

MIT License