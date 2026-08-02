variable "aws_region" {
  description = "AWS region to deploy into. Singapore for the APAC demo; the backend now follows this region automatically (boto3 uses AWS_REGION)."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix used for all resource names."
  type        = string
  default     = "pm-agent"
}

variable "environment" {
  description = "Deployment environment label (e.g. demo, prod)."
  type        = string
  default     = "demo"
}

# ── Bedrock ──────────────────────────────────────────────────
variable "bedrock_model_id" {
  description = <<-EOT
    Bedrock inference-profile ID the Lambda invokes. In ap-southeast-1, Claude is
    served via APAC cross-region inference profiles. CONFIRM the exact ID (it has a
    date/version suffix) from your account before the Lambda step:
      aws bedrock list-inference-profiles --region ap-southeast-1
    Only used at the Lambda step — not needed for the DynamoDB apply.
  EOT
  type        = string
  # PLACEHOLDER — replace with the exact Sonnet APAC profile ID from the command above.
  default = "apac.anthropic.claude-sonnet-4-6-v1:0"
}

# ── Lambda ───────────────────────────────────────────────────
variable "lambda_architecture" {
  description = "Lambda CPU architecture. arm64 (Graviton) is cheaper and matches an Apple-silicon build host."
  type        = string
  default     = "arm64"
}

variable "log_retention_days" {
  description = "CloudWatch log retention. Kept short to stay in the free tier."
  type        = number
  default     = 7
}

variable "lambda_memory" {
  description = "Lambda memory in MB (more memory = more CPU = faster orchestration + cold start)."
  type        = number
  default     = 1536
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds. The async chat endpoint runs the agent to completion here (the client polls for the result), so this is the true ceiling for a report's total time — set to 300s (5 min) so even a detailed all-projects report finishes and is saved before the Lambda is killed."
  type        = number
  default     = 300
}

variable "cloudfront_price_class" {
  description = "CloudFront price class. PriceClass_200 includes Asia edge locations (better for an APAC demo); still $0 at demo volume."
  type        = string
  default     = "PriceClass_200"
}

variable "frontend_bucket_name" {
  description = "Existing S3 bucket to reuse for the frontend. Empty = create a new one. If set to an existing bucket, `terraform import` it first (a bucket that already exists can't be created)."
  type        = string
  default     = ""
}

variable "public_api_base" {
  description = "Public base URL the backend uses to build absolute links (e.g. PPT downloads). After CloudFront exists, set to https://<cloudfront-domain>/api and re-apply. Empty = fall back to the raw API Gateway URL."
  type        = string
  default     = ""
}

# ── CORS ─────────────────────────────────────────────────────
variable "allowed_origins" {
  description = "Origins allowed to call the API (the CloudFront URL is added after the frontend is deployed)."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

# ── Secrets ──────────────────────────────────────────────────
variable "app_secrets" {
  description = <<-EOT
    Backend secrets pushed to SSM SecureString (Jira + Slack). Put REAL values in
    a gitignored terraform.tfvars — never commit them. Each key becomes an env var
    name inside the Lambda (e.g. JIRA_API_TOKEN). Do NOT include JWT_SECRET here —
    it is generated automatically.
  EOT
  type        = map(string)
  default     = {}
}
