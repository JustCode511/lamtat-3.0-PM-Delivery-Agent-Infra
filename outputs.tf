output "dynamodb_tables" {
  description = "Created DynamoDB table names."
  value = {
    sessions       = aws_dynamodb_table.sessions.name
    users          = aws_dynamodb_table.users.name
    revoked_tokens = aws_dynamodb_table.revoked_tokens.name
    conversations  = aws_dynamodb_table.conversations.name
    memory         = aws_dynamodb_table.memory.name
    jobs           = aws_dynamodb_table.jobs.name
  }
}

output "ssm_param_prefix" {
  description = "SSM path prefix the Lambda reads its secrets from (set as SSM_PARAM_PREFIX on the Lambda)."
  value       = local.ssm_prefix
}

output "api_url" {
  description = "Public HTTPS base URL for the backend API — use this as the frontend's API base and add it to ALLOWED_ORIGINS."
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "lambda_function_name" {
  description = "Deployed Lambda function name (for logs: aws logs tail /aws/lambda/<name>)."
  value       = aws_lambda_function.api.function_name
}

output "frontend_url" {
  description = "HTTPS URL of the deployed frontend (CloudFront)."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "frontend_bucket" {
  description = "S3 bucket to sync the built frontend into."
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation after each deploy)."
  value       = aws_cloudfront_distribution.frontend.id
}
