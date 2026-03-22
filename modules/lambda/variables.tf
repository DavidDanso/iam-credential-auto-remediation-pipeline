variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alert notifications"
  type        = string
}

variable "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for the Lambda function"
  type        = string
}

variable "guardduty_detector_id" {
  description = "GuardDuty detector ID used in IAM policy scoping"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda function memory allocation in MB"
  type        = number
  default     = 128
}
