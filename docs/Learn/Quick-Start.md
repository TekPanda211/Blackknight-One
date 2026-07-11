\# Quick Start



> \*\*Estimated time:\*\* 5–10 minutes  

> \*\*Audience:\*\* Microsoft 365 Administrators, Identity Engineers, Security Engineers, Microsoft Partners, and IT Professionals



> \[!NOTE]

> Blackknight One is currently in \*\*v0.5.0-alpha\*\*. Features and documentation are actively evolving as the platform continues to mature. We welcome feedback, bug reports, feature requests, and suggestions through the GitHub repository.



\---



\# Learning Path



This guide is part of the Blackknight One learning path.



```text

Getting Started

&#x20;     │

&#x20;     ▼

Installation

&#x20;     │

&#x20;     ▼

Quick Start

&#x20;     │

&#x20;     ▼

Platform Architecture

&#x20;     │

&#x20;     ▼

Platform Overview

&#x20;     │

&#x20;     ▼

Engine Documentation

&#x20;     │

&#x20;     ▼

Command Reference

```



\---



\# Overview



This guide demonstrates the fastest way to experience Blackknight One.



In less than ten minutes you will:



\- Connect to Microsoft Graph

\- Discover your Microsoft Entra tenant

\- Assess your Zero Trust posture

\- Correlate identities

\- Generate reports

\- Display the operational dashboard



No configuration is required beyond the installation completed in the previous guide.



\---



\# Step 1 — Import the Platform



Load the Blackknight One platform.



```powershell

Import-Module `

&#x20;   .\\scripts\\PowerShell\\Platform\\Blackknight-Platform.psm1 `

&#x20;   -Force

```



\---



\# Step 2 — Validate the Platform



Verify the platform is healthy.



```powershell

Test-BKPlatform

```



Expected output:



```text

PASS Platform



PASS Services



PASS Engines



PASS Reports



PASS PowerShell Syntax

```



\---



\# Step 3 — Connect to Microsoft Graph



Authenticate.



```powershell

Connect-BKGraph

```



Sign in using an account with Microsoft Graph permissions.



\---



\# Step 4 — Discover Your Tenant



Collect tenant information.



```powershell

Get-BKTenant

```



Expected output:



```text

Tenant Name



Tenant ID



Users



Groups



Guests



Domains



Licenses

```



\---



\# Step 5 — Run an Identity Assessment



Execute Identity Discovery.



```powershell

.\\scripts\\PowerShell\\Identity\\Invoke-BKIdentityDiscovery.ps1

```



The Identity Engine inventories:



\- Organization

\- Users

\- Groups

\- Domains

\- Licensing



Results are exported automatically.



\---



\# Step 6 — Evaluate Trust



Run the Trust Engine.



```powershell

.\\scripts\\PowerShell\\Trust\\Invoke-BKTrustDiscovery.ps1

```



Blackknight evaluates:



\- Conditional Access

\- MFA

\- Passwordless

\- SSPR

\- Named Locations



Recommendations are generated automatically.



\---



\# Step 7 — Correlate Identities



Execute the Correlation Engine.



```powershell

.\\scripts\\PowerShell\\Correlation\\Invoke-BKCorrelation.ps1

```



Identity correlation combines:



\- Identity

\- Authentication

\- Authorization

\- Trust



into a unified operational model.



\---



\# Step 8 — Display the Dashboard



Display the platform dashboard.



```powershell

Show-BKDashboard

```



Example:



```text

==========================================================

&#x20;                BLACKKNIGHT ONE

&#x20;     Enterprise Identity Engineering Platform

==========================================================



Platform



Tenant



Identity



Trust



Governance



Operations



Overall Platform Confidence



Recommendations

```



\---



\# What Just Happened?



In only a few commands Blackknight One has:



\- Connected to Microsoft Graph

\- Discovered your tenant

\- Inventoried users and groups

\- Evaluated Conditional Access

\- Reviewed authentication readiness

\- Correlated identities

\- Generated reports

\- Calculated confidence scores

\- Produced actionable recommendations



This demonstrates the core workflow of the platform.



\---



\# Generated Reports



Reports are automatically written to:



```text

reports/



identity/



trust/



correlation/



validation/

```



These JSON reports can be consumed by:



\- Power BI

\- Microsoft Sentinel

\- SIEM platforms

\- Automation workflows

\- CI/CD validation pipelines



\---



\# Explore Additional Commands



Continue exploring the platform with:



```powershell

Get-BKPlatform



Get-BKPlatformInventory



Get-BKCapabilities



Get-BKDirectoryRoles



Show-BKAuthenticationMethodsSummary



Find-BKIdentity



Show-BKIdentity



Find-BKDirectoryRoleAssignment



Show-BKDashboard

```



\---



\# Where to Go Next



You have now completed your first Blackknight One assessment.



Continue learning:



\- Platform Architecture

\- Platform Overview

\- Identity Engine

\- Trust Engine

\- Correlation Engine

\- Validation Engine

\- Command Reference



\---



\# Typical Daily Workflow



Most administrators can assess a tenant using the following workflow:



```powershell

Import-Module .\\scripts\\PowerShell\\Platform\\Blackknight-Platform.psm1 -Force



Test-BKPlatform



Connect-BKGraph



.\\scripts\\PowerShell\\Identity\\Invoke-BKIdentityDiscovery.ps1



.\\scripts\\PowerShell\\Trust\\Invoke-BKTrustDiscovery.ps1



.\\scripts\\PowerShell\\Correlation\\Invoke-BKCorrelation.ps1



Show-BKDashboard

```



\---



\# Related Documentation



| Document | Description |

|----------|-------------|

| Getting Started | Introduction to Blackknight One |

| Installation | Install and configure the platform |

| Platform Architecture | Learn how the platform is designed |

| Platform Overview | Understand the major platform components |

| Identity Engine | Learn about identity discovery |

| Trust Engine | Learn about Zero Trust assessments |

| Command Reference | Complete list of supported commands |



\---



\## About Blackknight One



Blackknight One is an Enterprise Identity Engineering Platform that unifies Microsoft Graph discovery, identity correlation, trust assessment, Terraform integration, validation, and engineering automation into a single operational experience.



Its long-term vision is to provide organizations with \*\*One Source of Truth\*\* for Enterprise Identity Engineering.



\---



\*\*Next Guide\*\*



\*\*Platform Architecture\*\*

