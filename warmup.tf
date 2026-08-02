# ── Keep the Lambda warm (free) ──────────────────────────────
# EventBridge pings GET /health every 5 minutes so one execution environment
# stays warm — eliminating the ~4s cold start. Cost: ~8.6k tiny invocations/month,
# well within Lambda's free tier (1M req + 400k GB-s) → $0.

resource "aws_cloudwatch_event_rule" "warmup" {
  name                = "${var.project_name}-${var.environment}-warmup"
  description         = "Keep the pm-agent Lambda warm (ping /health every 5 min)"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "warmup" {
  rule      = aws_cloudwatch_event_rule.warmup.name
  target_id = "lambda"
  arn       = aws_lambda_function.api.arn

  # Synthetic API Gateway v2 event for GET /health so Mangum processes it normally
  # (returns {"status":"ok"} without touching DynamoDB/Bedrock).
  input = jsonencode({
    version        = "2.0"
    routeKey       = "$default"
    rawPath        = "/health"
    rawQueryString = ""
    headers        = { "x-warmup" = "true" }
    requestContext = {
      http = {
        method   = "GET"
        path     = "/health"
        protocol = "HTTP/1.1"
        sourceIp = "127.0.0.1"
      }
    }
    body            = ""
    isBase64Encoded = false
  })
}

resource "aws_lambda_permission" "warmup" {
  statement_id  = "AllowEventBridgeWarmup"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.warmup.arn
}
