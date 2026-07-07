resource "azuread_group" "department_groups" {
  for_each = {
    for group in flatten([
      for dept in local.departments : [
        for type in local.group_types : {
          name = "${local.company_prefix}-${dept}-${type}"
        }
      ]
    ]) : group.name => group
  }

  display_name     = each.value.name
  security_enabled = true

  description = "Terraform-managed IAM lab group for ${each.value.name}"
}