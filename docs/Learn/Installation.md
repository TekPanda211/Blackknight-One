\# Install Blackknight One



> \*\*Estimated time:\*\* 15–20 minutes  

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



This guide walks through installing Blackknight One and its dependencies.



After completing this guide you will have:



\- PowerShell installed

\- Microsoft Graph PowerShell SDK installed

\- Blackknight One downloaded

\- Platform validated

\- Ready for your first assessment



\---



\# System Requirements



Blackknight One currently supports:



| Component | Requirement |

|------------|-------------|

| Operating System | Windows 10/11 or Windows Server |

| PowerShell | Version 7.4 or later (recommended) |

| Microsoft Graph SDK | Current release |

| Git | Recommended |

| Internet Access | Required for Microsoft Graph |

| Microsoft Entra Tenant | Required |



\---



\# Verify PowerShell



Verify the installed version.



```powershell

$PSVersionTable.PSVersion

```



Example:



```text

Major Minor Patch

\----- ----- -----

7     5     1

```



If PowerShell 7 is not installed, download it from:



https://github.com/PowerShell/PowerShell



\---



\# Install Git



Git is recommended for cloning and updating the repository.



Verify installation:



```powershell

git --version

```



If Git is not installed:



https://git-scm.com/downloads



\---



\# Install Microsoft Graph PowerShell



Install the Microsoft Graph SDK.



```powershell

Install-Module Microsoft.Graph `

&#x20;   -Scope CurrentUser

```



Update later using:



```powershell

Update-Module Microsoft.Graph

```



Verify installation:



```powershell

Get-Module Microsoft.Graph -ListAvailable

```



\---



\# Clone the Repository



Clone Blackknight One.



```powershell

git clone https://github.com/<YOUR-GITHUB>/blackknight-one



cd blackknight-one

```



\---



\# Repository Layout



The repository is organized into several functional areas.



```text

blackknight-one



docs/

scripts/

terraform/

schemas/

reports/

configurations/

```



\---



\# Import the Platform



Load the platform module.



```powershell

Import-Module `

&#x20;   .\\scripts\\PowerShell\\Platform\\Blackknight-Platform.psm1 `

&#x20;   -Force

```



Verify the module loaded successfully.



```powershell

Get-Module Blackknight-Platform

```



\---



\# Validate the Installation



Run the platform validator.



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



Every validation should pass before continuing.



\---



\# Authenticate to Microsoft Graph



Connect using:



```powershell

Connect-BKGraph

```



Sign in using an account with sufficient Microsoft Graph permissions.



\---



\# Verify Connectivity



Confirm the connection.



```powershell

Get-BKTenant

```



Expected output:



```text

Tenant Name



Tenant ID



Users



Groups



Domains

```



\---



\# Updating Blackknight One



To update your local copy:



```powershell

git pull

```



Reload the module.



```powershell

Remove-Module Blackknight-Platform



Import-Module `

&#x20;   .\\scripts\\PowerShell\\Platform\\Blackknight-Platform.psm1 `

&#x20;   -Force

```



Re-run validation.



```powershell

Test-BKPlatform

```



\---



\# Common Installation Issues



\## PowerShell Module Won't Import



Verify your working directory.



```powershell

Get-Location

```



\---



\## Microsoft Graph SDK Missing



Install:



```powershell

Install-Module Microsoft.Graph `

&#x20;   -Scope CurrentUser

```



\---



\## Authentication Fails



Verify:



\- Internet connectivity

\- Microsoft Entra permissions

\- Microsoft Graph SDK installation



\---



\## Test-BKPlatform Reports Failures



Review each reported issue before continuing.



\---



\# Best Practices



Recommended workflow:



\- Keep Microsoft Graph PowerShell updated.

\- Pull the latest Blackknight One changes before assessments.

\- Run `Test-BKPlatform` after every update.

\- Review release notes before upgrading.

\- Use a dedicated PowerShell 7 session for Blackknight One.



\---



\# Next Steps



Your installation is complete.



Continue with:



\- Quick Start

\- Platform Architecture

\- Platform Overview

\- Identity Engine

\- Trust Engine



\---



\# Related Documentation



| Document | Purpose |

|----------|---------|

| Getting Started | Introduction to Blackknight One |

| Quick Start | Complete your first assessment |

| Platform Architecture | Understand the platform design |

| Command Reference | Explore every supported command |



\---



\## About Blackknight One



Blackknight One is an Enterprise Identity Engineering Platform designed to unify Microsoft Graph discovery, Terraform infrastructure, identity correlation, validation, confidence scoring, and engineering automation into a single operational experience.



\---



\*\*Next Guide\*\*



\*\*Quick Start\*\*

