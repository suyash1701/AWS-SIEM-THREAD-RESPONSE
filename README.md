# Automated Cloud Threat Detection & Response on AWS

A personal lab project that detects threats in an AWS account and responds automatically, built with Terraform and Python.

## What it does

1. **AWS GuardDuty** analyzes VPC Flow Logs, CloudTrail events, and DNS logs for suspicious activity.
2. An **EventBridge rule** catches findings with severity 7 or higher.
3. Three **Lambda functions** (Python) run automatically:
   - `isolate_ec2.py` moves a compromised EC2 instance into a quarantine security group with no traffic allowed, and tags it `Status=quarantined`.
   - `revoke_iam.py` sets an exposed IAM access key to Inactive (it does not delete it, so it can be investigated). A protected-user list prevents locking out the admin.
   - `notify_slack.py` posts a readable alert to a Slack channel.

## Architecture

```
GuardDuty finding (severity >= 7)
        |
   EventBridge rule
        |
        +--> Lambda: isolate EC2
        +--> Lambda: revoke IAM key
        +--> Lambda: notify Slack
```

## Tech stack

AWS GuardDuty, EventBridge, Lambda (Python 3.12), EC2, IAM, CloudWatch Logs, Terraform, Slack Incoming Webhooks.

## Project structure

```
terraform/   main.tf, ec2.tf, detection.tf, response.tf
lambda/      notify_slack.py, isolate_ec2.py, revoke_iam.py
test/        sample events used to test the Lambdas
```

## How to deploy

Requirements: AWS CLI, Terraform >= 1.6, Python 3.12, an AWS account, and a Slack webhook.

```powershell
cd terraform
$env:TF_VAR_slack_webhook_url = "<your-slack-webhook-url>"
terraform init
terraform plan
terraform apply
```

## How to test

1. Create a sample GuardDuty finding:
   ```powershell
   aws guardduty create-sample-findings --detector-id <detector-id> --finding-types "Backdoor:EC2/C&CActivity.B!DNS"
   ```
   A Slack alert should arrive within a few minutes.
2. Test isolation on a real test instance by invoking the Lambda with a JSON event that contains its instance ID:
   ```powershell
   aws lambda invoke --function-name siem-isolate-ec2 --payload fileb://test/isolate_event.json out.json
   ```

## Results

- Alert pipeline tested end to end with a GuardDuty sample finding.
- EC2 isolation tested on a real instance; the Lambda ran in about 2 seconds.
- IAM key disabling tested on a throwaway user.

## Clean up

```powershell
terraform destroy
```

The quarantine security group is created by the Lambda, so delete it manually afterwards. Remove the Slack webhook and any test IAM users.

## Security notes

- Never commit the Slack webhook URL or `terraform.tfstate` (the state file contains the webhook value).
- Lambda permissions use `Resource = "*"` to keep the lab simple. A production setup should scope them down.

## Possible improvements

- Take an EBS snapshot before isolating an instance, for forensics.
- Add a human approval step for high-impact actions.
- Narrow IAM permissions to specific resources.
- Handle more finding types and add retries and error alerts.
- Measure full detection-to-response time.
