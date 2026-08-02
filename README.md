# pm-agent-infra

Terraform for deploying the **AABG-FY26 AI Delivery Intelligence** platform (PM +
Talent + FinOps agents) to AWS — cost-effectively, with **~$0 idle cost**.
Part of the AABG-FY26 project (Accenture × AWS).

## Architecture

```
CloudFront ──► /          ──► private S3 bucket (React SPA, via Origin Access Control)
           └─► /api/*      ──► API Gateway (HTTP API) ──► Lambda (arm64, py3.13, Mangum + FastAPI)
                (strip_api CloudFront Function                 ├─► Amazon Bedrock (Claude Sonnet 4.6)
                 rewrites /api/x → /x)                         ├─► DynamoDB × 6 (on-demand)
                                                               ├─► SSM Parameter Store (secrets)
                                                               ├─► self-invoke (async chat jobs)
                                                               └─► Cost Explorer etc. (FinOps, read-only)
EventBridge ──► GET /health every 5 min (keeps the Lambda warm — free)
```

Same-origin `/api` (CloudFront routes it to API Gateway) → no CORS, no per-environment
frontend config.

## What it provisions

- **AWS Lambda** — the FastAPI app via Mangum (`APP_ENV=aws`, `LLM_PROVIDER=bedrock`),
  arm64/Graviton, `python3.13`, **300 s** timeout. Also runs the **background job worker**
  (async chat) via self-invocation. (`lambda.tf`)
- **API Gateway (HTTP API)** — public HTTPS in front of the Lambda. (`apigateway.tf`)
- **CloudFront + private S3** — HTTPS SPA over a private bucket (OAC); a CloudFront
  Function strips the `/api` prefix before forwarding to API Gateway. (`s3_cloudfront.tf`)
- **DynamoDB (on-demand)** — **6 tables**: `pm_sessions`, `pm_users`, `pm_revoked_tokens`,
  `pm_conversations` (GSI `user_id-index`), `pm_memory`, `pm_jobs` (TTL). (`dynamodb.tf`)
- **Amazon Bedrock** — the LLM (invoked by the Lambda; IAM permission only, no infra).
- **IAM role** — least-privilege: DynamoDB, Bedrock, SSM + KMS, CloudWatch Logs,
  **self-invoke** (async jobs), and **read-only FinOps** APIs (Cost Explorer, Budgets,
  Compute Optimizer, EC2 describe). (`iam.tf`)
- **SSM Parameter Store** — secrets (`JWT_SECRET`, Jira/Slack creds) as SecureStrings. (`ssm.tf`)
- **EventBridge** — pings `/health` every 5 min to avoid cold starts (free tier). (`warmup.tf`)
- **CloudWatch Logs** — 7-day retention (free-tier friendly).

## Prerequisites

- Terraform >= 1.6  (`brew install terraform`)
- AWS CLI configured  (`aws configure`) — verify with `aws sts get-caller-identity`
- **Bedrock model access enabled** for `global.anthropic.claude-sonnet-4-6` in the
  account (Bedrock console → Model catalog → submit the one-time use-case form)
- Python 3.13 + a backend virtualenv at `../pm-agent-backend/.venv` (used by `build_lambda.sh`)

## Usage

> ⚠️ **Build the Lambda package first.** `build_lambda.sh` installs arm64 Linux wheels and
> copies the backend source into `build/package/`; Terraform's `archive_file` then zips it.
> Run it **before every `terraform apply`** and **again whenever the backend code changes**.

```bash
cp terraform.tfvars.example terraform.tfvars   # put REAL Jira/Slack secrets here (gitignored)
terraform init

bash build_lambda.sh                           # → build/package/  (REQUIRED before apply)
terraform plan
terraform apply
```

Redeploy just the Lambda code after a backend change:
```bash
bash build_lambda.sh && terraform apply -target=aws_lambda_function.api
```

Tear everything down after the demo:
```bash
terraform destroy
```

## Files

| File | Purpose |
|---|---|
| `lambda.tf` | Lambda function, log groups, package zip |
| `apigateway.tf` | HTTP API + `$default` route + invoke permission |
| `s3_cloudfront.tf` | Private S3 + CloudFront + OAC + `strip_api` function |
| `dynamodb.tf` | 6 on-demand tables |
| `iam.tf` | Least-privilege role (DynamoDB, Bedrock, SSM/KMS, logs, self-invoke, FinOps) |
| `ssm.tf` | SecureString secrets from `app_secrets` + generated `JWT_SECRET` |
| `warmup.tf` | EventBridge `/health` ping (keep-warm) |
| `variables.tf` / `outputs.tf` | Inputs (region, model id, timeouts, origins) / URLs & names |
| `providers.tf` / `versions.tf` | AWS provider + version pins |
| `build_lambda.sh` | Builds `build/package/` (run before apply) |

Useful outputs after `apply`: `frontend_url` (CloudFront), `api_url` (API Gateway),
`lambda_function_name`, `cloudfront_distribution_id`, `dynamodb_tables`.

## Notes

- **State is local** and gitignored (it can contain secrets in plaintext). Fine for a
  single-operator demo; switch to an S3 backend for team use.
- **Secrets are not in this repo.** They load into SSM at apply time from a gitignored
  `terraform.tfvars`; `terraform.tfvars.example` holds placeholders only.
- **Region:** `ap-southeast-1` (Singapore) for the APAC demo — the backend follows
  `AWS_REGION` automatically.
- The frontend SPA is deployed separately: `npm run build` then `aws s3 sync dist/` into
  the bucket + a CloudFront invalidation (see the frontend repo's README).
