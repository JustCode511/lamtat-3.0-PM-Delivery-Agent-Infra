# ── Secrets in SSM Parameter Store (SecureString) ────────────
# The backend loads these into env at cold start (shared/aws_secrets.py) via the
# SSM_PARAM_PREFIX env var, so no secret value ever sits in the Lambda's env
# config — the Lambda only holds the prefix + IAM permission to read the params.
#
# JWT_SECRET is generated here. Jira/Slack values come from var.app_secrets,
# which you set in a gitignored terraform.tfvars.

locals {
  # e.g. /pm-agent/demo  → params live at /pm-agent/demo/JWT_SECRET, etc.
  ssm_prefix = "/${var.project_name}/${var.environment}"

  # Iterate over the parameter NAMES (not secret) — for_each can't take a
  # sensitive value. The value for each key is resolved inside the resource.
  secret_keys = toset(concat(keys(var.app_secrets), ["JWT_SECRET"]))
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false # 64 alphanumeric chars = ample entropy, and shell/URL-safe
}

resource "aws_ssm_parameter" "app" {
  for_each = local.secret_keys

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "SecureString"
  value = each.key == "JWT_SECRET" ? random_password.jwt_secret.result : var.app_secrets[each.key]
}
