variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

# Zip each Python file so AWS can run it
data "archive_file" "notify" {
  type        = "zip"
  source_file = "${path.module}/../lambda/notify_slack.py"
  output_path = "${path.module}/notify_slack.zip"
}

data "archive_file" "isolate" {
  type        = "zip"
  source_file = "${path.module}/../lambda/isolate_ec2.py"
  output_path = "${path.module}/isolate_ec2.zip"
}

data "archive_file" "revoke" {
  type        = "zip"
  source_file = "${path.module}/../lambda/revoke_iam.py"
  output_path = "${path.module}/revoke_iam.zip"
}

# The identity (role) the Lambdas run as
resource "aws_iam_role" "lambda_role" {
  name = "siem-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets Lambdas write logs
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lets Lambdas isolate servers and disable keys
resource "aws_iam_role_policy" "response_actions" {
  name = "siem-response-actions"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:ModifyInstanceAttribute",
        "ec2:CreateTags",
        "iam:UpdateAccessKey"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "notify" {
  function_name    = "siem-notify-slack"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "notify_slack.lambda_handler"
  filename         = data.archive_file.notify.output_path
  source_code_hash = data.archive_file.notify.output_base64sha256
  timeout          = 15
  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_lambda_function" "isolate" {
  function_name    = "siem-isolate-ec2"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "isolate_ec2.lambda_handler"
  filename         = data.archive_file.isolate.output_path
  source_code_hash = data.archive_file.isolate.output_base64sha256
  timeout          = 30
}

resource "aws_lambda_function" "revoke" {
  function_name    = "siem-revoke-iam"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "revoke_iam.lambda_handler"
  filename         = data.archive_file.revoke.output_path
  source_code_hash = data.archive_file.revoke.output_base64sha256
  timeout          = 30
}
# The rule: catch GuardDuty findings with severity 7 or higher
resource "aws_cloudwatch_event_rule" "high_severity" {
  name        = "siem-high-severity-findings"
  description = "GuardDuty findings with severity >= 7"
  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

# Rule starts all three Lambdas
resource "aws_cloudwatch_event_target" "notify" {
  rule = aws_cloudwatch_event_rule.high_severity.name
  arn  = aws_lambda_function.notify.arn
}

resource "aws_cloudwatch_event_target" "isolate" {
  rule = aws_cloudwatch_event_rule.high_severity.name
  arn  = aws_lambda_function.isolate.arn
}

resource "aws_cloudwatch_event_target" "revoke" {
  rule = aws_cloudwatch_event_rule.high_severity.name
  arn  = aws_lambda_function.revoke.arn
}

# Give EventBridge permission to run each Lambda
resource "aws_lambda_permission" "notify" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.high_severity.arn
}

resource "aws_lambda_permission" "isolate" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.isolate.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.high_severity.arn
}

resource "aws_lambda_permission" "revoke" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.revoke.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.high_severity.arn
}