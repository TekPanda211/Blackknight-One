# BlackKnight One Architecture

## Overview

BlackKnight One is a modular PowerShell platform for infrastructure, identity, and security assessments.

The platform provides a unified dashboard-driven experience while separating user interaction, public interfaces, assessment engines, reporting, and shared platform services.

The architecture is designed around independent assessment engines that share common reporting, scoring, and wrapper patterns.

---

# High-Level Architecture

```
                           BlackKnight One

                           Show-BKDashboard
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        │                          │                          │
   Terraform                  Microsoft Graph            Platform
        │                          │                          │
        │                          │                          │
        ▼                          ▼                          ▼

 Assessment Engine         Tenant Discovery           Reports
 HCL Discovery             Graph Assessment           Settings
 Security Analysis         Identity Assessment        About
 Plan Analysis
 Drift Detection
```

---

# Platform Layers

BlackKnight One follows a layered architecture.

```
Dashboard

↓

Public Platform Wrappers

↓

Assessment Engines

↓

Shared Platform Services

↓

External Platforms
```

Each layer has a single responsibility.

---

# Dashboard Layer

Primary Entry Point

```
Show-BKDashboard
```

The dashboard provides a consistent user experience and serves as the primary entry point for all platform capabilities.

Responsibilities include:

- User navigation
- Platform selection
- Tenant selection
- Assessment execution
- Report access
- Platform information

The dashboard replaces the need to memorize individual PowerShell commands.

---

# Public Wrapper Layer

Public wrappers provide a stable interface for assessment engines.

Examples include:

```
Invoke-BKTerraformAssessment

Invoke-BKTerraformHclDiscovery

Invoke-BKTerraformSecurityAnalysis

Test-BKTerraformDrift

Invoke-BKGraphAssessment

Get-BKTenantDiscovery
```

Responsibilities include:

- Parameter validation
- Consistent verbose output
- Error handling
- Engine discovery
- Report path handling
- Result normalization

Business logic is intentionally kept out of wrappers.

---

# Assessment Engine Layer

Assessment engines perform all analysis.

Each engine is independent and can execute individually or as part of a larger assessment workflow.

## Terraform

Current engines include:

- Terraform Assessment
- HCL Discovery Engine v2
- Security Analysis
- Configuration Validation
- Execution Plan Analysis
- Two-Phase Drift Detection

---

## Microsoft Graph

Current engines include:

- Tenant Discovery
- Graph Assessment

Planned:

- Identity Assessment
- Conditional Access Assessment
- Privileged Identity Assessment
- Application Permission Assessment

---

# Terraform Assessment Workflow

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

Each phase contributes to the overall assessment score and executive recommendation.

---

# Reporting Layer

Every assessment produces a standardized object model.

```
Summary

Scores

Findings

Recommendations

Metadata
```

Reports may be exported as JSON for automation, archival, or integration with external systems.

---

# Scoring Model

Current Terraform assessment weighting:

| Component | Weight |
|-----------|-------:|
| Inventory | 10% |
| HCL Architecture | 15% |
| Security Analysis | 25% |
| Configuration Validation | 20% |
| Plan Analysis | 15% |
| Drift Confirmation | 15% |

Scores are combined into:

- Overall Confidence
- Assessment Health
- Release Decision

---

# Repository Structure

```
scripts/
└── PowerShell
    ├── Platform
    │   ├── Public
    │   └── Private
    │
    ├── Terraform
    │   ├── Assessment
    │   ├── Discovery
    │   ├── Security
    │   ├── Drift
    │   └── Reporting
    │
    ├── Graph
    │
    ├── Identity
    │
    └── Reporting
```

---

# Design Principles

## Dashboard First

Users should be able to perform all common operations through the platform dashboard.

---

## Modular

Assessment engines remain independent and reusable.

---

## Consistent

All engines follow a common structure:

- Public Wrapper
- Assessment Engine
- Summary
- Scores
- Findings
- JSON Export

---

## Extensible

New assessment engines can be added without changing existing platform architecture.

---

## Executive Reporting

Every assessment produces information useful to both engineers and leadership.

---

# Current Platform Components

| Component | Status |
|-----------|--------|
| Dashboard | Complete |
| Terraform Assessment | Complete |
| Terraform HCL Discovery v2 | Complete |
| Terraform Security Analyzer | Complete |
| Terraform Plan Analysis | Complete |
| Terraform Drift Detection | Complete |
| Microsoft Graph Tenant Discovery | Complete |
| Microsoft Graph Assessment | Complete |
| JSON Reporting | Complete |

---

# Planned Components

The following engines are planned as the platform continues to grow.

## Microsoft Identity

- Identity Assessment
- Conditional Access Assessment
- Privileged Identity Management Assessment
- Application Permissions Assessment

## Microsoft 365

- Exchange Online Assessment
- SharePoint Online Assessment
- Teams Assessment
- Intune Assessment

## Azure

- Subscription Assessment
- Resource Inventory
- Policy Assessment
- Cost Analysis

---

# Long-Term Vision

BlackKnight One is designed to become a unified assessment platform for infrastructure, identity, security, and Microsoft cloud services.

Rather than focusing on a single technology, the platform provides a consistent assessment experience across multiple domains while producing standardized reporting suitable for engineering teams, consultants, managed service providers, and enterprise environments.