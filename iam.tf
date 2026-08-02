# ── IAM role for the Lambda ──────────────────────────────────
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-${var.environment}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_perms" {
  # CloudWatch Logs — the Lambda's own group + the observability /lamtat/chat group
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
  }

  # Custom CloudWatch metrics (observability) — PutMetricData has no resource scope
  statement {
    sid       = "Metrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  # DynamoDB CRUD on the 5 tables + the conversations GSI
  statement {
    sid = "DynamoDB"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.sessions.arn,
      aws_dynamodb_table.users.arn,
      aws_dynamodb_table.revoked_tokens.arn,
      aws_dynamodb_table.conversations.arn,
      "${aws_dynamodb_table.conversations.arn}/index/*",
      aws_dynamodb_table.memory.arn,
      aws_dynamodb_table.jobs.arn,
    ]
  }

  # Bedrock — invoke Claude. Cross-region inference (APAC profile) routes across
  # regions, so we allow invoke broadly; tighten to specific profile ARNs later.
  statement {
    sid       = "Bedrock"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["*"]
  }

  # Self-invoke — POST /pm/chat/async fires a background (Event) invocation of
  # THIS same function so the request returns instantly (no 30s cap / 504).
  # ARN is constructed (not a resource ref) to avoid a role⇄function cycle.
  statement {
    sid       = "SelfInvoke"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-${var.environment}"]
  }

  # SSM — read the app secrets. GetParametersByPath authorizes against the PATH
  # node itself (…:parameter/pm-agent/demo); GetParameter authorizes each child
  # (…/pm-agent/demo/*). Grant both.
  statement {
    sid     = "SSMRead"
    actions = ["ssm:GetParametersByPath", "ssm:GetParameters", "ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*",
    ]
  }

  # KMS — decrypt SecureString params (via the default aws/ssm key)
  statement {
    sid       = "KMSDecryptViaSSM"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.project_name}-${var.environment}-lambda-perms"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_perms.json
}
