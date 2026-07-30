# pm-agent-infra

Terraform for deploying the **AABG-FY26 PM Delivery Agent** to AWS, cost-effectively
with zero idle cost. Part of the AABG-FY26 project (Accenture × AWS).

## What it provisions (backend, phase 1)

- **AWS Lambda** — runs the FastAPI app via Mangum (`APP_ENV=aws`, `LLM_PROVIDER=bedrock`)
- **API Gateway (HTTP API)** — public HTTPS endpoint in front of the Lambda
- **DynamoDB (on-demand)** — 4 tables: `pm_sessions`, `pm_users`, `pm_revoked_tokens`, `pm_conversations`
- **Amazon Bedrock** — the LLM (invoked by the Lambda; IAM permission only, no infra)
- **IAM role** — least-privilege access to the tables, Bedrock, SSM, and logs
- **SSM Parameter Store** — secrets (`JWT_SECRET`, Jira/Slack creds) as SecureStrings
- **CloudWatch Logs** — 7-day retention (free-tier friendly)

Frontend (phase 2): **S3 + CloudFront** for the static React SPA.

## Prerequisites

- Terraform >= 1.6  (`brew install terraform`)
- AWS CLI configured with valid credentials  (`aws configure`) — verify with `aws sts get-caller-identity`
- Bedrock model access **enabled in the target region's console** (Bedrock → Model access)

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit if needed
terraform init
terraform plan
terraform apply
```

Tear everything down after the demo:

```bash
terraform destroy
```

## Notes

- **State is local** and gitignored (it can contain secrets in plaintext). Fine for a
  single-operator demo; switch to an S3 backend for team use.
- Secrets are **not** stored in this repo. They go into SSM at apply time from a
  gitignored `terraform.tfvars` (or `-var` / environment).
