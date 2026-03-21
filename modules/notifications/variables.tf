variable "project_name" {
  description = "Project name"
  type        = string
}

variable "alert_email" {
  description = "Alert email address"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}
