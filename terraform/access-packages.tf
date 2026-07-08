# Identity Governance / Access Packages Framework
#
# This file defines the desired Identity Governance and Entitlement Management
# model for BlackKnight One.
#
# NOTE:
# These locals define the governance model only.
# Future releases will use Terraform and/or Microsoft Graph automation to
# deploy, discover, and validate Access Packages, catalogs, assignment policies,
# access reviews, and lifecycle workflows.

locals {
  access_catalogs = {
    workforce = {
      display_name = "Workforce Access"
      description  = "Standard employee access including new hire, department, manager, and executive access."
    }

    privileged = {
      display_name = "Privileged Access"
      description  = "Elevated administrative access governed by approval, expiration, and review."
    }

    contractor = {
      display_name = "Contractor Access"
      description  = "Temporary access for contractors, vendors, and external workforce users."
    }

    applications = {
      display_name = "Application Access"
      description  = "Application-specific access for business systems, SaaS platforms, and enterprise applications."
    }

    guests = {
      display_name = "Guest Collaboration"
      description  = "External collaboration access for business partners, customers, legal, and audit users."
    }
  }

  access_packages = {
    new_hire_baseline = {
      catalog     = "workforce"
      name        = "New Hire Baseline"
      description = "Baseline access package for new employees."
      duration    = "365 days"
      approval    = "Manager"
      review      = "Quarterly"
    }

    it_department_access = {
      catalog     = "workforce"
      name        = "IT Department Access"
      description = "Standard access package for IT department users."
      duration    = "365 days"
      approval    = "Manager"
      review      = "Quarterly"
    }

    security_department_access = {
      catalog     = "workforce"
      name        = "Security Department Access"
      description = "Standard access package for security department users."
      duration    = "365 days"
      approval    = "Manager"
      review      = "Quarterly"
    }

    contractor_baseline = {
      catalog     = "contractor"
      name        = "Contractor Baseline"
      description = "Baseline temporary access package for contractors."
      duration    = "90 days"
      approval    = "Sponsor"
      review      = "Monthly"
    }

    temporary_project_access = {
      catalog     = "contractor"
      name        = "Temporary Project Access"
      description = "Time-bound project access package."
      duration    = "30 days"
      approval    = "Project Owner"
      review      = "Monthly"
    }

    privileged_admin_access = {
      catalog     = "privileged"
      name        = "Privileged Admin Access"
      description = "Governed privileged administrative access package."
      duration    = "8 hours"
      approval    = "Security"
      review      = "Monthly"
    }
  }
}
