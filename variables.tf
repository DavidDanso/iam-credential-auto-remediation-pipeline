variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS subscription"
  type        = string
}

variable "project_name" {
  description = "Used as a prefix for resource naming"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 30
}
