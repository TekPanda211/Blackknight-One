output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "created_groups" {
  value = [
    for group in azuread_group.department_groups : group.display_name
  ]
}