resource "azuread_group" "role_assignable_groups" {
  for_each = toset(local.privileged_groups)

  display_name       = "${local.naming_prefix}-${each.value}-RoleAssignable"
  description        = "${var.environment} role-assignable Microsoft Entra ID group managed by Terraform for ${each.value}."
  security_enabled   = true
  assignable_to_role = true
}