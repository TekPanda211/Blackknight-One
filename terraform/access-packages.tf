# Access Packages Framework
#
# This file defines the future Identity Governance and Entitlement Management
# structure for BlackKnight One.
#
# Access Package deployment requires Microsoft Entra ID Governance licensing
# and may require Microsoft Graph-backed automation depending on provider support.

locals {
  access_package_catalogs = [
    "Workforce Access",
    "Privileged Access",
    "Contractor Access",
    "Application Access"
  ]

  access_package_templates = [
    "New Hire Baseline",
    "IT Department Access",
    "Security Department Access",
    "Contractor Baseline",
    "Temporary Project Access",
    "Privileged Admin Access"
  ]
}