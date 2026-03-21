variable "project_name" {
  description = "Project name"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN"
  type        = string
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  type        = string
}
