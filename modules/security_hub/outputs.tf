output "security_hub_id" {
  value       = aws_securityhub_account.main.id
  description = "The AWS account ID where Security Hub is enabled"
}
