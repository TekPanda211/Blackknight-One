\# BlackKnight One Dashboard



\## Overview



The BlackKnight One Dashboard is the primary entry point for the platform.



Rather than requiring users to remember individual PowerShell commands, the dashboard provides a centralized, menu-driven interface for launching assessments, viewing reports, and managing platform operations.



The dashboard is intended to be the standard way users interact with BlackKnight One.



\---



\# Launching the Dashboard



Import the platform module.



```powershell

Import-Module .\\scripts\\PowerShell\\Platform\\Blackknight-Platform.psm1

```



Start the dashboard.



```powershell

Show-BKDashboard

```



\---



\# Dashboard Layout



```

============================================================

&#x20;                   BLACKKNIGHT ONE

============================================================



Terraform

\------------------------------------------------------------

1\. Complete Terraform Assessment

2\. Terraform HCL Discovery

3\. Terraform Security Analysis

4\. Terraform Drift Detection

5\. Terraform Plan Analysis



Microsoft Graph

\------------------------------------------------------------

6\. Tenant Discovery

7\. Graph Assessment

8\. Identity Assessment



Platform

\------------------------------------------------------------

9\. Reports

10\. Settings

11\. About

12\. Exit

```



> \*\*Note:\*\* The available menu items may expand as new platform capabilities are added.



\---



\# Dashboard Workflow



The dashboard follows a simple workflow.



```

Start Dashboard



↓



Select Platform



↓



Choose Assessment



↓



(Optional) Connect to Microsoft Graph



↓



Run Assessment



↓



View Results



↓



Export Reports

```



\---



\# Microsoft Graph Connections



Microsoft Graph assessments require authentication.



When a Graph-based assessment is selected, the dashboard prompts for the tenant to connect to before executing the assessment.



Supported authentication scenarios include:



\- Microsoft Entra ID

\- Microsoft 365

\- Azure tenants

\- Delegated authentication



The dashboard establishes the connection before launching the selected assessment engine.



\---



\# Terraform Operations



Terraform assessments operate against a specified Terraform project directory.



Current Terraform capabilities include:



\- Complete Assessment

\- HCL Discovery Engine v2

\- Security Analysis

\- Drift Detection

\- Execution Plan Analysis



Most Terraform operations support:



\- Verbose logging

\- JSON report export

\- Executive summaries

\- Confidence scoring



\---



\# Microsoft Graph Operations



Current Microsoft Graph capabilities include:



\- Tenant Discovery

\- Graph Assessment



Discovery collects information such as:



\- Organization

\- Domains

\- Users

\- Groups

\- Devices

\- Service Principals

\- Licenses



Assessment results include:



\- Dataset coverage

\- Inventory coverage

\- Executive findings

\- Confidence score



\---



\# Reports



Assessment engines support JSON report generation.



Reports are written beneath the configured report directory.



Typical output includes:



```

reports/



terraform/



graph/



identity/



security/

```



Each assessment generates a report that includes:



\- Summary

\- Scores

\- Findings

\- Recommendations

\- Metadata



\---



\# About



The About screen displays platform information including:



\- Platform name

\- Version

\- Release information

\- Repository

\- Copyright



\---



\# Design Principles



The dashboard was designed around the following principles.



\## Single Entry Point



Users begin with one command:



```powershell

Show-BKDashboard

```



\## Consistent Navigation



Every platform component follows the same navigation model.



\## Discoverability



Available assessments are visible from the dashboard without requiring knowledge of PowerShell command names.



\## Extensibility



New assessment engines can be added to the dashboard without changing the user experience.



\---



\# Current Dashboard Features



| Feature | Status |

|----------|--------|

| Interactive Menu | Complete |

| Terraform Menu | Complete |

| Microsoft Graph Menu | Complete |

| Tenant Selection | Complete |

| Assessment Launching | Complete |

| Report Integration | Complete |

| About Screen | Complete |



\---



\# Planned Enhancements



Future dashboard capabilities include:



\- Identity Assessment menu

\- Conditional Access Assessment

\- Exchange Online Assessment

\- SharePoint Online Assessment

\- Intune Assessment

\- Azure Assessment

\- HTML report viewer

\- Assessment history

\- User preferences

\- Configuration management

\- Automatic update notification



\---



\# Recommended Usage



For most users, the dashboard should be the primary interface to BlackKnight One.



Advanced users may still execute assessment engines directly when integrating with automation or custom workflows, but interactive use is expected to begin with:



```powershell

Show-BKDashboard

```

