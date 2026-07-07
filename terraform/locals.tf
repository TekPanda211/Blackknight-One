locals {
  company_prefix = var.company_prefix

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
}