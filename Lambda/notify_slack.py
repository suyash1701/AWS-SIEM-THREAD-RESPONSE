import json
import os
import urllib.request


def send_to_slack(message):
    url = os.environ["SLACK_WEBHOOK_URL"]
    data = json.dumps({"text": message}).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    urllib.request.urlopen(req, timeout=10)


def lambda_handler(event, context):
    detail = event.get("detail", {})
    title = detail.get("title", "Test alert")
    severity = detail.get("severity", "unknown")
    finding_type = detail.get("type", "unknown")
    region = event.get("region", "unknown")

    message = (
        f":rotating_light: *GuardDuty alert*\n"
        f"*Title:* {title}\n"
        f"*Severity:* {severity}\n"
        f"*Type:* {finding_type}\n"
        f"*Region:* {region}"
    )
    send_to_slack(message)
    return {"status": "sent"}