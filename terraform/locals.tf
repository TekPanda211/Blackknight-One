locals {

  naming_prefix = "${var.company_prefix}-${var.environment}"

  departments = [
    "IT",
    "Engineering",
    "Security",
    "HR",
    "Finance",
    "Sales",
    "Marketing",
    "Support",
    "Contractors"
  ]

  group_types = [
    "Users",
    "Admins",
    "Readers"
  ]

  privileged_groups = [
    "IT-Admins",
    "Security-Admins",
    "Engineering-Admins"
  ]
}