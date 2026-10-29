import sys

sys.path.insert(0, "lambda")
import notify_slack

fake_event = {
    "region": "us-east-1",
    "detail": {
        "title": "Test: EC2 instance is talking to a bad IP",
        "severity": 8,
        "type": "Backdoor:EC2/C&CActivity.B",
    },
}

print(notify_slack.lambda_handler(fake_event, None))