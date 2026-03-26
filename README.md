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

### Full End-to-End Test (Recommended)

This test validates the complete remediation path against a real IAM identity — access key deactivation, login profile deletion, SNS alert delivery, and CloudWatch logging.

**1. Get your AWS account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```

**2. Create a throwaway test user with a real access key and login profile:**
```bash
aws iam create-user --user-name compromised-test-user
aws iam create-access-key --user-name compromised-test-user
aws iam create-login-profile --user-name compromised-test-user --password 'TempPass123!@#' --password-reset-required
```

Save the `AccessKeyId` returned from the second command.

**3. Invoke the Lambda directly with a crafted payload:**
```bash
aws lambda invoke \
  --function-name $(terraform output -raw lambda_function_name) \
  --payload '{"version":"0","id":"test-001","detail-type":"GuardDuty Finding","source":"aws.guardduty","detail":{"schemaVersion":"2.0","accountId":"<your_account_id>","region":"<your_region>","type":"CredentialAccess:IAMUser/AnomalousBehavior","severity":8,"createdAt":"2026-01-01T00:00:00Z","id":"test-finding-001","resource":{"resourceType":"AccessKey","accessKeyDetails":{"userType":"IAMUser","userName":"compromised-test-user","accessKeyId":"<AccessKeyId>","userAccount":"<your_account_id>"}}}}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json
```

Replace `<your_account_id>`, `<your_region>`, and `<AccessKeyId>` with real values.

Expected response:
```json
{"statusCode": 200, "body": "Remediation complete. Status: SUCCESS"}
```

**4. Verify the remediation happened in AWS:**
```bash
# Access key must show Status: Inactive
aws iam list-access-keys --user-name compromised-test-user

# Login profile must return NoSuchEntity (Lambda deleted it)
aws iam get-login-profile --user-name compromised-test-user
```

**5. Check your email inbox** — confirm the structured JSON alert arrived with `remediation_status: SUCCESS` and `affected_principal.username: compromised-test-user`.

**6. Clean up the test user (in this exact order):**
```bash
aws iam delete-access-key --user-name compromised-test-user --access-key-id <AccessKeyId>
aws iam delete-user --user-name compromised-test-user
```

> Login profile was already deleted by Lambda — skip that step.

---

### EventBridge Routing Verification

This test confirms EventBridge is correctly wired to Lambda. It uses a fabricated GuardDuty identity so IAM remediation will fail — that is expected. The only thing being verified here is that the routing works.

```bash
aws guardduty create-sample-findings \
  --detector-id $(terraform output -raw guardduty_detector_id) \
  --finding-types 'CredentialAccess:IAMUser/AnomalousBehavior'
```

Wait 2 minutes, then check CloudWatch Logs for a Lambda invocation triggered by EventBridge.

---

### Verify the Pipeline

After running either test:

- **CloudWatch Logs** — check `/aws/lambda/<project_name>-remediate` for Lambda invocation logs
- **Email** — confirm a structured JSON alert arrived in your inbox
- **Security Hub** — navigate to Security Hub CSPM → Findings and confirm GuardDuty findings are visible

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