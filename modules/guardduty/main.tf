resource "aws_guardduty_detector" "primary" {
  enable                       = true
  finding_publishing_frequency = "SIX_HOURS"

  tags = {
    Name    = "${var.project_name}-guardduty"
    Project = var.project_name
  }
}
