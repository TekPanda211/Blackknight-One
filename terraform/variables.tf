variable "company_prefix" {
  description = "Organization prefix used for naming Microsoft Entra ID resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment."

  type = string

  validation {
    condition     = contains(["Lab", "Dev", "Test", "Prod"], var.environment)
    error_message = "Environment must be Lab, Dev, Test, or Prod."
  }
}