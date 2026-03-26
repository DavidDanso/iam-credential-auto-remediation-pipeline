# Threat Detection & Auto-Remediation Pipeline

An automated AWS security pipeline that detects threats via Amazon GuardDuty, remediates compromised IAM identities in real time using AWS Lambda, sends structured alerts via Amazon SNS, and aggregates findings in AWS Security Hub — all provisioned and managed through Terraform.

## Architecture

```
GuardDuty ──▶ EventBridge ──▶ Lambda (Python 3.12) ──▶ IAM Remediation
                                       │
                                       ├──▶ SNS (Email Alert)
                                       └──▶ CloudWatch Logs

GuardDuty ──▶ Security Hub (automatic integration)
```

**Services used:**

| Service | Purpose |
|---|---|
| Amazon GuardDuty | Continuous threat detection |
| Amazon EventBridge | Routes specific finding types to Lambda |
| AWS Lambda | Executes automated IAM remediation |
| Amazon SNS | Sends structured JSON alerts via email |
| Amazon CloudWatch | Stores Lambda execution logs |
| AWS Security Hub | Aggregates findings for compliance visibility |
| AWS IAM | Least-privilege execution role for Lambda |

**GuardDuty finding types monitored:**

- `UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.NoMFA`
- `UnauthorizedAccess:IAMUser/MaliciousIPCaller.Custom`
- `Recon:IAMUser/MaliciousIPCaller`
- `CredentialAccess:IAMUser/AnomalousBehavior`

## Remediation Logic

When a matching finding is detected, the Lambda function:

1. **Deactivates all access keys** for the compromised IAM user
2. **Deletes the login profile** (console password) for `IAMUser` principals
3. **Logs a skip** for `AssumedRole` principals (roles cannot be disabled directly)
4. **Publishes a structured JSON alert** to SNS with full remediation details
5. **Reports `SUCCESS` or `PARTIAL_FAILURE`** based on action outcomes

## Project Structure

```
threat-detection-pipeline/
├── main.tf                  # Root module composition
├── variables.tf             # Root-level input variables
├── outputs.tf               # Root-level outputs
├── terraform.tfvars         # Variable values (user-specific)
├── modules/
│   ├── guardduty/           # GuardDuty detector
│   ├── eventbridge/         # EventBridge rule, target, Lambda permission
│   ├── lambda/              # Lambda function, IAM role, deployment package
│   ├── notifications/       # SNS topic, email subscription, CloudWatch log group
│   └── security_hub/        # Security Hub account enablement
└── lambda_src/
    └── remediate.py         # Python remediation handler
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with valid credentials (`aws configure`)
- An AWS account with permissions to create IAM roles, Lambda functions, GuardDuty, SNS, EventBridge, CloudWatch, and Security Hub resources
- A valid email address for SNS alert delivery

## Deployment

1. **Clone the repository:**
   ```bash
   git clone https://github.com/DavidDanso/threat-detection-pipeline.git
   cd threat-detection-pipeline
   ```

2. **Configure variables** — edit `terraform.tfvars`:
   ```hcl
   aws_region   = "us-east-1"
   alert_email  = "your-email@example.com"
   project_name = "threat-pipeline"
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the execution plan:**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

6. **Confirm the SNS email subscription** — check your inbox and click the AWS confirmation link. Alerts will not be delivered until this is done.

## Testing

**Generate a sample GuardDuty finding:**

```bash
aws guardduty create-sample-findings \
  --detector-id $(terraform output -raw guardduty_detector_id) \
  --finding-types 'CredentialAccess:IAMUser/AnomalousBehavior'
```

**Verify the pipeline:**

- **CloudWatch Logs** — check `/aws/lambda/<project_name>-remediate` for Lambda invocation logs
- **Email** — confirm a structured JSON alert arrived in your inbox
- **Security Hub** — navigate to Findings and confirm GuardDuty findings are visible

## Cost Note

- **GuardDuty** offers a 30-day free trial. After the trial, finding analysis is billed per GB of data volume analyzed.
- **Lambda**, **SNS**, **CloudWatch**, and **EventBridge** costs are minimal for this use case and typically fall within the AWS Free Tier.
- **Security Hub** has a 30-day free trial. After that, pricing is based on the number of security checks and finding ingestion events.

## Teardown

> **⚠️ Warning:** Running `terraform destroy` will disable GuardDuty and Security Hub. In a real production account, this is a **security regression** — you will lose continuous threat monitoring. Only destroy in development or sandbox environments.

```bash
terraform destroy
```

## Outputs

| Output | Description |
|---|---|
| `guardduty_detector_id` | GuardDuty detector ID |
| `sns_topic_arn` | SNS topic ARN for alerts |
| `lambda_function_arn` | Lambda function ARN |
| `lambda_function_name` | Lambda function name |
| `event_rule_arn` | EventBridge rule ARN |
