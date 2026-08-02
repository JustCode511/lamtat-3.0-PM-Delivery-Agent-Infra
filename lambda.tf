# ── Lambda deployment package ────────────────────────────────
# Run ./build_lambda.sh first — it populates build/package/ (arm64 deps + source);
# this zips it. The source_dir must exist before `terraform plan/apply`.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/build/package"
  output_path = "${path.module}/build/lambda.zip"
}

# ── Log groups (7-day retention → free-tier friendly) ────────
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
}

# Observability module writes structured events here (created up-front so it
# has retention; the app's create_log_group then no-ops on AlreadyExists).
resource "aws_cloudwatch_log_group" "observability" {
  name              = "/lamtat/chat"
  retention_in_days = var.log_retention_days
}

# ── Lambda function ──────────────────────────────────────────
resource "aws_lambda_function" "api" {
  function_name    = "${var.project_name}-${var.environment}"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.13"
  handler          = "main.handler"
  architectures    = [var.lambda_architecture]
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  environment {
    variables = {
      APP_ENV          = "aws"
      LLM_PROVIDER     = "bedrock"
      BEDROCK_MODEL_ID = var.bedrock_model_id
      SSM_PARAM_PREFIX = local.ssm_prefix
      ALLOWED_ORIGINS  = join(",", var.allowed_origins)
      APP_BASE_URL     = var.public_api_base != "" ? var.public_api_base : aws_apigatewayv2_api.http.api_endpoint
      JWT_EXPIRY_HOURS = "24"
      # AWS_REGION is provided automatically by the Lambda runtime (reserved).
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
