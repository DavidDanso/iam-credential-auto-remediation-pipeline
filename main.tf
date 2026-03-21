provider "aws" {
  region = var.aws_region
}

module "guardduty" {
  source       = "./modules/guardduty"
  aws_region   = var.aws_region
  project_name = var.project_name
}

# module "eventbridge" {
#   source = "./modules/eventbridge"
# }

# module "lambda" {
#   source = "./modules/lambda"
# }

# module "notifications" {
#   source = "./modules/notifications"
# }
