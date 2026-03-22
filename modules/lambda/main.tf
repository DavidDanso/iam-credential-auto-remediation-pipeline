data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/lambda_src"
  output_path = "${path.module}/lambda_payload.zip"
}

resource "aws_lambda_function" "remediate" {
  function_name    = "${var.project_name}-remediate"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "remediate.handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      LOG_LEVEL     = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_attach
  ]
}
