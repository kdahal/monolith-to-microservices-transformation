variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "RG name"
  type        = string
  default     = "monolith-to-micro-rg"
}

variable "admin_password" {
  description = "SQL admin password"
  type        = string
  sensitive   = true
}